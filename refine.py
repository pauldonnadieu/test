#!/usr/bin/env python3
"""
Iterative Refinement System for Claude Code
============================================

This script drives a Plan → Execute → Evaluate loop using Claude Code's
two key capabilities:

  1. Plan mode  — Claude analyzes the current state (read-only) before acting.
  2. Self-reflection — a separate Evaluator Claude instance scores the result
     and provides feedback that feeds into the next iteration.

The loop runs until one of three stop conditions is met:
  - Score reaches the target (default: 95/100)
  - Improvement per iteration drops below the threshold (diminishing returns)
  - The maximum number of iterations is reached

Usage:
    python3 refine.py \\
        --task   "Write a Python function that sorts a list of dicts by a key" \\
        --goal   "Correct, efficient, handles edge cases, has docstring" \\
        [--work-dir      ./my_project]   # where Claude works (default: cwd)
        [--max-iterations 8]             # hard cap on loop count (default: 8)
        [--threshold      5]             # min improvement to continue (default: 5)
        [--target-score   95]            # score at which we declare success (default: 95)
        [--verbose]                      # print plans, execution summaries, scores
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path


# ── Helpers ─────────────────────────────────────────────────────────────────

def run_claude(
    prompt: str,
    work_dir: str,
    permission_mode: str | None = None,
    session_id: str | None = None,
    allowed_tools: list[str] | None = None,
    max_turns: int = 15,
) -> dict:
    """
    Run a single Claude Code CLI invocation and return its parsed JSON output.

    Why subprocess?
    The claude_agent_sdk Python package is not available in this environment.
    The CLI (`claude -p`) provides everything we need: JSON output, session IDs,
    permission mode control, and session resumption via --resume.

    Args:
        prompt:          The natural-language instruction to send.
        work_dir:        The directory Claude will treat as its working directory.
        permission_mode: "plan" for read-only (no writes), None for full access.
        session_id:      Resume a previous session (carries full context forward).
        allowed_tools:   List of tools to pre-approve, e.g. ["Read","Edit","Bash"].
        max_turns:       Limits the internal agentic loop depth.

    Returns:
        Parsed JSON dict with keys: result, session_id, num_turns, is_error, etc.
    """
    # -p takes the prompt as its direct argument: claude -p "text" [flags...]
    cmd = [
        "claude",
        "-p", prompt,
        "--output-format", "json",    # machine-readable structured output
        "--max-turns", str(max_turns),
    ]

    if permission_mode:
        cmd += ["--permission-mode", permission_mode]

    if session_id:
        cmd += ["--resume", session_id]

    if allowed_tools:
        cmd += ["--allowedTools", ",".join(allowed_tools)]

    try:
        result = subprocess.run(
            cmd,
            cwd=work_dir,
            capture_output=True,
            text=True,
            timeout=300,   # 5 minutes per Claude call — generous but bounded
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError("Claude timed out after 5 minutes")
    except FileNotFoundError:
        raise RuntimeError(
            "claude CLI not found. Ensure Claude Code is installed and on PATH."
        )

    if result.returncode != 0 and not result.stdout:
        raise RuntimeError(
            f"claude exited with code {result.returncode}.\n"
            f"stderr: {result.stderr[:500]}"
        )

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(
            f"Failed to parse claude JSON output: {e}\n"
            f"Raw output: {result.stdout[:500]}"
        )


def parse_score(result_text: str) -> dict:
    """
    Extract a structured evaluation from the Evaluator's result text.

    The Evaluator is prompted to return JSON. It may wrap it in a markdown
    code fence (```json ... ```), so we strip that first.

    Expected shape:
        {
          "score":        75,
          "feedback":     "The function is correct but lacks edge case handling.",
          "improvements": ["Handle empty list input", "Add type hints"]
        }

    Returns a dict with the above keys, with safe defaults if parsing fails.
    """
    # Strip markdown code fences that Claude often adds around JSON
    cleaned = re.sub(r"```(?:json)?\s*", "", result_text).strip()
    cleaned = re.sub(r"```\s*$", "", cleaned).strip()

    # Find the first JSON object in the text
    match = re.search(r"\{.*\}", cleaned, re.DOTALL)
    if not match:
        print(f"  [warning] Could not find JSON in evaluator output. Raw:\n  {result_text[:300]}")
        return {"score": 0, "feedback": result_text[:300], "improvements": []}

    try:
        data = json.loads(match.group())
        return {
            "score":        int(data.get("score", 0)),
            "feedback":     str(data.get("feedback", "")),
            "improvements": list(data.get("improvements", [])),
        }
    except (json.JSONDecodeError, ValueError) as e:
        print(f"  [warning] Could not parse evaluation JSON: {e}")
        return {"score": 0, "feedback": result_text[:300], "improvements": []}


def should_stop(scores: list[int], threshold: int, window: int = 2) -> bool:
    """
    Detect diminishing returns.

    We look at the average improvement over the last `window` iterations.
    If that average is below `threshold`, further iterations are unlikely
    to produce meaningful gains.

    Why window=2?
    A single unusually small step (e.g. a hard sub-problem that takes two
    iterations to crack) shouldn't terminate the run. Two consecutive small
    improvements are a stronger signal that we've plateaued.

    Args:
        scores:    Score history, oldest first.
        threshold: Minimum average improvement (in score points) to continue.
        window:    How many recent improvements to average.

    Returns:
        True if the loop should stop.
    """
    if len(scores) < 2:
        return False

    # Compute improvement for each adjacent pair in the recent window
    start = max(1, len(scores) - window)
    recent_improvements = [scores[i] - scores[i - 1] for i in range(start, len(scores))]
    avg_improvement = sum(recent_improvements) / len(recent_improvements)

    return avg_improvement < threshold


# ── The Three Phases ─────────────────────────────────────────────────────────

def plan_phase(
    task: str,
    goal: str,
    iteration: int,
    work_dir: str,
    previous_feedback: str,
    previous_improvements: list[str],
    verbose: bool,
) -> tuple[str, str]:
    """
    PLAN PHASE (read-only, permission_mode="plan").

    Why plan mode?
    It restricts Claude to read-only tools. This forces thorough exploration
    before any action, and prevents accidental changes during analysis.
    The session_id is captured so the Worker can resume with full context.

    Returns:
        (plan_text, session_id)
    """
    # Build a context-rich prompt. In iteration 1 there's no prior feedback;
    # from iteration 2 onwards we inject the evaluator's specific suggestions.
    if iteration == 1:
        context = "This is the first iteration — start from a clean analysis."
    else:
        improvement_list = "\n".join(f"  - {imp}" for imp in previous_improvements)
        context = (
            f"Previous evaluator feedback:\n  {previous_feedback}\n\n"
            f"Specific improvements to address:\n{improvement_list}"
        )

    prompt = f"""You are the PLANNER in an iterative refinement loop.

TASK: {task}
GOAL: {goal}

ITERATION: {iteration}
CONTEXT: {context}

Your job (read-only analysis):
1. Explore the current state of the work directory thoroughly.
2. Identify the specific gaps between what exists and the GOAL.
3. Write a concrete, numbered action plan for the WORKER to execute.
   - Be specific: name files, functions, and exact changes needed.
   - Do NOT make changes yourself — only plan.

End your response with a section headed "## Action Plan" containing numbered steps."""

    if verbose:
        print(f"\n  [planner] Running plan mode for iteration {iteration}...")

    response = run_claude(
        prompt=prompt,
        work_dir=work_dir,
        permission_mode="plan",
        allowed_tools=["Read", "Glob", "Grep", "WebSearch"],
        max_turns=10,
    )

    plan_text = response.get("result", "")
    session_id = response.get("session_id", "")

    if verbose:
        print(f"  [planner] Session ID: {session_id}")
        # Extract and print just the Action Plan section
        if "## Action Plan" in plan_text:
            action_plan = plan_text.split("## Action Plan", 1)[1].strip()
            print(f"  [planner] Action Plan:\n    " + action_plan[:600].replace("\n", "\n    "))

    return plan_text, session_id


def execute_phase(
    goal: str,
    plan_session_id: str,
    work_dir: str,
    verbose: bool,
) -> str:
    """
    EXECUTE PHASE (full tool access, resumes the planner's session).

    Why --resume?
    The Worker inherits the Planner's entire context — the file reads,
    analysis, and written plan — without repeating that exploration work.
    This makes execution faster and more focused.

    Returns:
        Summary of what was done.
    """
    prompt = """You are the WORKER in an iterative refinement loop.

You have full access to read and write files and run commands.

Review the Action Plan from your previous analysis and execute it step by step.
- Make real changes to files.
- Run tests or checks if relevant to verify your work.
- Prefer targeted improvements over wholesale rewrites.
- After completing all steps, write a brief summary of what you changed."""

    if verbose:
        print(f"\n  [worker] Executing plan (resuming session {plan_session_id[:8]}...)...")

    response = run_claude(
        prompt=prompt,
        work_dir=work_dir,
        session_id=plan_session_id,
        allowed_tools=["Read", "Edit", "Write", "Bash", "Glob", "Grep"],
        max_turns=20,
    )

    result = response.get("result", "")
    turns = response.get("num_turns", "?")

    if verbose:
        print(f"  [worker] Completed in {turns} turns.")
        print(f"  [worker] Summary: {result[:300]}")

    return result


def evaluate_phase(
    task: str,
    goal: str,
    iteration: int,
    work_dir: str,
    verbose: bool,
) -> dict:
    """
    EVALUATE PHASE (read-only, fresh session — no --resume).

    Why a fresh session?
    The Evaluator must be unbiased. If it shared context with the Worker,
    it might unconsciously justify the choices made rather than judging
    the result against the goal. Starting fresh ensures it evaluates
    the actual state of the work, not the intent behind it.

    Returns:
        {"score": int, "feedback": str, "improvements": list[str]}
    """
    prompt = f"""You are the EVALUATOR in an iterative refinement loop.

TASK: {task}
GOAL: {goal}

Your job:
1. Explore the current state of the work directory.
2. Assess how well the current state satisfies the GOAL.
3. Be honest and critical — inflated scores are counterproductive.

Scoring rubric:
  0–30:  Little or no progress toward the goal.
  31–60: Partial progress; major gaps remain.
  61–80: Substantial progress; notable gaps remain.
  81–95: Very good; only minor improvements possible.
  96–100: Goal fully satisfied; no meaningful improvements left.

Respond with ONLY valid JSON (no prose, no markdown fences):
{{
  "score":        <integer 0-100>,
  "feedback":     "<one paragraph explaining the score>",
  "improvements": ["<specific actionable improvement 1>", "<improvement 2>", ...]
}}"""

    if verbose:
        print(f"\n  [evaluator] Scoring iteration {iteration} (fresh session)...")

    response = run_claude(
        prompt=prompt,
        work_dir=work_dir,
        permission_mode="plan",
        allowed_tools=["Read", "Glob", "Grep"],
        max_turns=8,
    )

    raw = response.get("result", "")
    evaluation = parse_score(raw)

    if verbose:
        print(f"  [evaluator] Score: {evaluation['score']}/100")
        print(f"  [evaluator] Feedback: {evaluation['feedback'][:200]}")

    return evaluation


# ── Main Loop ────────────────────────────────────────────────────────────────

def run_refinement_loop(
    task: str,
    goal: str,
    work_dir: str,
    max_iterations: int,
    threshold: int,
    target_score: int,
    verbose: bool,
) -> None:
    """
    Orchestrate the Plan → Execute → Evaluate → Decide loop.

    Each iteration:
      1. Planner analyzes state and writes a plan (read-only).
      2. Worker resumes the planner's session and executes the plan.
      3. Evaluator scores the result from scratch (fresh session).
      4. We check stop conditions and carry feedback forward.

    Stop conditions (in priority order):
      a. score >= target_score  (goal achieved)
      b. diminishing_returns()  (not worth continuing)
      c. iteration == max_iterations  (hard cap)
    """
    print(f"\n{'='*60}")
    print("  ITERATIVE REFINEMENT SYSTEM")
    print(f"{'='*60}")
    print(f"  Task:           {task}")
    print(f"  Goal:           {goal}")
    print(f"  Work directory: {work_dir}")
    print(f"  Max iterations: {max_iterations}")
    print(f"  Threshold:      {threshold} points improvement to continue")
    print(f"  Target score:   {target_score}/100")
    print(f"{'='*60}\n")

    scores: list[int] = []
    history: list[dict] = []
    feedback = ""
    improvements: list[str] = []
    start_time = datetime.now()

    for i in range(1, max_iterations + 1):
        print(f"\n{'─'*60}")
        print(f"  ITERATION {i}/{max_iterations}")
        print(f"{'─'*60}")

        # ── Phase 1: Plan ──────────────────────────────────────────────
        plan_text, plan_session_id = plan_phase(
            task=task,
            goal=goal,
            iteration=i,
            work_dir=work_dir,
            previous_feedback=feedback,
            previous_improvements=improvements,
            verbose=verbose,
        )

        if not plan_session_id:
            print("  [error] Planner did not return a session ID. Stopping.")
            break

        # ── Phase 2: Execute ───────────────────────────────────────────
        execution_summary = execute_phase(
            goal=goal,
            plan_session_id=plan_session_id,
            work_dir=work_dir,
            verbose=verbose,
        )

        # ── Phase 3: Evaluate ──────────────────────────────────────────
        evaluation = evaluate_phase(
            task=task,
            goal=goal,
            iteration=i,
            work_dir=work_dir,
            verbose=verbose,
        )

        score = evaluation["score"]
        feedback = evaluation["feedback"]
        improvements = evaluation["improvements"]
        scores.append(score)

        # Record for final report
        history.append({
            "iteration":   i,
            "score":       score,
            "feedback":    feedback,
            "improvements": improvements,
        })

        # Progress indicator
        improvement_str = ""
        if len(scores) >= 2:
            delta = scores[-1] - scores[-2]
            sign = "+" if delta >= 0 else ""
            improvement_str = f"  ({sign}{delta} vs previous)"
        print(f"\n  Score: {score}/100{improvement_str}")

        # ── Phase 4: Decide ────────────────────────────────────────────
        if score >= target_score:
            print(f"\n  Target score {target_score} reached. Stopping.")
            break

        if should_stop(scores, threshold):
            avg_recent = (scores[-1] - scores[-2]) if len(scores) >= 2 else 0
            print(
                f"\n  Diminishing returns detected "
                f"(avg improvement {avg_recent:.1f} < threshold {threshold}). Stopping."
            )
            break

        if i < max_iterations:
            print(f"  Continuing to iteration {i + 1}...")

    # ── Final Report ──────────────────────────────────────────────────────
    elapsed = datetime.now() - start_time
    print(f"\n\n{'='*60}")
    print("  FINAL REPORT")
    print(f"{'='*60}")
    print(f"  Iterations run:  {len(history)}")
    print(f"  Elapsed time:    {elapsed}")
    print(f"\n  Score progression:")
    for record in history:
        bar = "█" * (record["score"] // 5)
        print(f"    Iteration {record['iteration']:2d}: {record['score']:3d}/100  {bar}")

    if history:
        final = history[-1]
        print(f"\n  Final score:     {final['score']}/100")
        print(f"  Final feedback:  {final['feedback']}")
        if final["improvements"]:
            print(f"\n  Remaining improvements:")
            for imp in final["improvements"]:
                print(f"    - {imp}")

    print(f"\n{'='*60}\n")


# ── CLI ───────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Iteratively refine a task using Claude Code's plan mode and self-reflection.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--task", required=True,
        help="What Claude should do (e.g. 'Write a binary search function').",
    )
    parser.add_argument(
        "--goal", required=True,
        help="Success criteria (e.g. 'Correct, efficient, handles edge cases, documented').",
    )
    parser.add_argument(
        "--work-dir", default=".",
        help="Directory where Claude works. Defaults to current directory.",
    )
    parser.add_argument(
        "--max-iterations", type=int, default=8,
        help="Hard cap on the number of refinement cycles. Default: 8.",
    )
    parser.add_argument(
        "--threshold", type=int, default=5,
        help=(
            "Minimum average score improvement (points) needed to continue. "
            "Below this, diminishing returns are declared. Default: 5."
        ),
    )
    parser.add_argument(
        "--target-score", type=int, default=95,
        help="Score at which the goal is considered fully achieved. Default: 95.",
    )
    parser.add_argument(
        "--verbose", action="store_true",
        help="Print plan text, execution summaries, and raw evaluation output.",
    )

    args = parser.parse_args()

    work_dir = str(Path(args.work_dir).resolve())
    if not Path(work_dir).is_dir():
        print(f"Error: --work-dir '{work_dir}' is not a directory.")
        sys.exit(1)

    run_refinement_loop(
        task=args.task,
        goal=args.goal,
        work_dir=work_dir,
        max_iterations=args.max_iterations,
        threshold=args.threshold,
        target_score=args.target_score,
        verbose=args.verbose,
    )


if __name__ == "__main__":
    main()
