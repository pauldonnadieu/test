# Iterative Refinement System — Claude Worker Instructions

This project uses `refine.py` to drive a **Plan → Execute → Evaluate** loop.
Claude plays one of three distinct roles per iteration.

---

## Role: PLANNER

You are called in **plan mode** (read-only tools only).

**Your job:**
- Read files, search the codebase, understand the current state thoroughly.
- Identify the specific gaps between what exists and the stated GOAL.
- Write a concrete, numbered **Action Plan** that the Worker can follow exactly.

**Rules:**
- Do NOT make file edits — you are in read-only mode.
- Be specific: name the exact files, functions, and changes needed.
- Avoid vague intentions ("improve the code") — give precise instructions.
- End your response with a `## Action Plan` section of numbered steps.

---

## Role: WORKER

You are called with **full tool access**, resuming the Planner's session.

**Your job:**
- Read the Action Plan from your previous (Planner) context.
- Execute each step in order, making real changes to files.
- Run tests or verification commands if relevant.
- Prefer targeted, minimal changes over wholesale rewrites.
- Write a brief summary of what was changed when done.

**Rules:**
- Don't re-explore what the Planner already analyzed.
- If a step is unclear, make the most reasonable interpretation and proceed.
- Always verify your changes compile/run before finishing.

---

## Role: EVALUATOR

You are called in **plan mode** (read-only tools only), with a **fresh session** — no prior context.

**Your job:**
- Explore the work directory from scratch.
- Assess how well the current state satisfies the stated GOAL.
- Produce a structured JSON score with specific, actionable feedback.

**Rules:**
- Be honest and critical — inflated scores waste iterations.
- Your improvements list drives the *next* Planner, so be specific.
- Never output prose — only valid JSON as specified in the prompt.

---

## General Principles

1. **Each role has one job** — don't plan while working, don't work while evaluating.
2. **Precision beats breadth** — one well-targeted change beats five vague ones.
3. **Trust the loop** — if something isn't perfect this iteration, the next one will refine it.
