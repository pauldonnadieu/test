# Iterative Refinement System

A system that uses Claude Code's **plan mode** and **self-reflection** to
iteratively improve any task until diminishing returns are detected.

## How It Works

Each iteration runs three Claude phases:

```
┌─────────────────────────────────────────────────────────┐
│  PLANNER  (read-only, plan mode)                        │
│  Explores current state → identifies gaps → writes plan │
└───────────────────────────┬─────────────────────────────┘
                            │ session resumed
┌───────────────────────────▼─────────────────────────────┐
│  WORKER   (full tools, same session)                    │
│  Executes the plan → makes real changes                 │
└───────────────────────────┬─────────────────────────────┘
                            │ fresh session (unbiased)
┌───────────────────────────▼─────────────────────────────┐
│  EVALUATOR  (read-only, fresh session)                  │
│  Scores result 0-100 → gives specific feedback          │
└───────────────────────────┬─────────────────────────────┘
                            │
                      Diminishing returns?
                      ┌─────┴─────┐
                     Yes          No
                      │           │
                    Stop      Next iteration
```

The evaluator's feedback feeds into the next Planner prompt, closing the loop.

### Stop Conditions

The loop stops when **any** of these are true:
- **Target score reached** — score >= 95 (configurable)
- **Diminishing returns** — average improvement < 5 points over last 2 iterations (configurable)
- **Hard cap** — maximum iterations reached (default: 8)

## Usage

```bash
python3 refine.py \
  --task   "Write a Python binary search function" \
  --goal   "Correct, O(log n), handles edge cases, has docstring and type hints" \
  --work-dir ./my_project \
  --verbose
```

### All Options

| Flag | Default | Description |
|------|---------|-------------|
| `--task` | *(required)* | What Claude should do |
| `--goal` | *(required)* | Success criteria to evaluate against |
| `--work-dir` | `.` (current dir) | Where Claude reads/writes files |
| `--max-iterations` | `8` | Hard cap on loop iterations |
| `--threshold` | `5` | Min score improvement to continue |
| `--target-score` | `95` | Score considered "done" |
| `--verbose` | off | Print plans, summaries, raw scores |

### Example Output

```
============================================================
  ITERATIVE REFINEMENT SYSTEM
============================================================
  Task:           Write a Python binary search function
  Goal:           Correct, O(log n), handles edge cases, documented
  Max iterations: 8
  Threshold:      5 points improvement to continue

------------------------------------------------------------
  ITERATION 1/8
------------------------------------------------------------
  Score: 62/100

  ITERATION 2/8
  Score: 78/100  (+16 vs previous)

  ITERATION 3/8
  Score: 84/100  (+6 vs previous)

  ITERATION 4/8
  Score: 87/100  (+3 vs previous)

  Diminishing returns detected (avg improvement 4.5 < threshold 5). Stopping.

============================================================
  FINAL REPORT
============================================================
  Iterations run:  4

  Score progression:
    Iteration  1:  62/100  ████████████
    Iteration  2:  78/100  ███████████████
    Iteration  3:  84/100  ████████████████
    Iteration  4:  87/100  █████████████████

  Final score:     87/100
```

## Prerequisites

- **Claude Code** installed and authenticated (`claude --version`)
- **Python 3.11+**

## Design Notes

**Why three separate roles?**
Separating Planner, Worker, and Evaluator prevents a single Claude instance
from both making and judging its own work in the same context. The fresh
Evaluator session is especially important — it evaluates the result against the
goal, not the intent behind it.

**Why `--resume` for Plan -> Execute?**
The Worker resumes the Planner's session so it inherits the full analysis
without repeating expensive file exploration.

**Why `CLAUDE.md`?**
Claude Code automatically reads `CLAUDE.md` in the work directory. It sets
clear expectations for each role, improving output quality without embedding
verbose instructions in the Python code.
