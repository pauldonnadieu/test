# Working on this build with Claude Code

How to drive the build effectively. This is about process; `BUILD.md` is about outcomes.

The recommendations here follow Anthropic's published guidance on Claude Code ([best practices](https://code.claude.com/docs/en/best-practices), [how Claude Code works](https://code.claude.com/docs/en/how-claude-code-works)). Where this document and that guidance diverge, the guidance is newer and wins.

---

## 1. The one thing that matters most

> Claude stops when the work looks done. Without a check it can run, "looks done" is the only signal available, and you become the verification loop.

So every stage of this build ships a script that returns pass or fail. Not a checklist a human reads. An executable check the agent can run, read the output of, and iterate against until it passes.

```
verify/
  stage1-host.sh
  stage2-container.sh
  stage3-core.sh
  stage5-rituals.sh
  stage6-scheduling.sh
  stage7-recovery.sh
  all.sh            runs every script that applies
```

**These are not build scaffolding.** They are the security regression suite. Every property that matters (nothing listening, no secret in `/data`, container cannot reach host root, hooks block what they claim to block) is a thing that can silently stop being true after an unrelated change six months later. A script that checks it is how you find out. `verify/all.sh` becomes part of the weekly audit in Stage 6 and stays for the life of the system.

**Write the check before or alongside the work, not after.** A check written afterwards tends to assert what was built rather than what was required.

**Show evidence, not assertions.** When a stage passes, the output of the script is the claim. "Stage 1 complete" on its own is not.

Three ways to make the check bind harder, in ascending order of setup cost:

- **In the prompt.** Ask for the check to be run and iterated on in the same message.
- **As a `/goal` condition.** An evaluator re-checks after every turn and work continues until it resolves.
- **As a Stop hook.** The check runs as a script and blocks the turn from ending until it passes. This is what lets an unattended run finish correctly.

---

## 2. One session per stage

Context is the binding constraint, and performance degrades as it fills. Eight stages in one session would spend most of its budget on history from stages already finished.

- Start a fresh session per stage. `/clear` between stages, or a new session entirely.
- Open with the stage goal and its definition of done, not the whole document.
- Name sessions after the stage so they can be resumed.
- Run `/context` if behaviour degrades. If early instructions seem to have been forgotten, they probably have been.

**If you have corrected the same mistake twice, stop correcting.** Clear the context and restart the stage with a better opening prompt that incorporates what you learned. A clean session with a sharper prompt beats a long session carrying failed approaches.

---

## 3. Explore, plan, then build

Worth the overhead on the stages where getting the approach wrong is expensive:

- **Stage 2** (container isolation), because the security properties are the point and they are easy to get subtly wrong.
- **Stage 3** (core and interface), because it touches many files at once.
- **Stage 7** (recovery), because the procedure has to be right before it is tested, not discovered during the test.
- **The companion app**, all of it.

Not worth it for Stage 0, or for anything whose diff could be described in one sentence.

Use plan mode (`Shift+Tab`, or `claude --permission-mode plan`) for the exploration, get the plan into a file, then implement in a fresh session against that file. A written plan the implementation session can read beats a plan held in a context window that is about to be compacted.

---

## 4. Stage 4 is an interview, and there is a documented pattern for it

The intake is the highest-leverage hour in the build, and Anthropic's own advice for large features maps onto it directly: have Claude interview the user before writing anything.

Use `AskUserQuestion`. Dig into the hard parts rather than asking obvious questions. Keep going until the ground is covered, then write the result out. Then **start a fresh session** to act on it, so the implementation has clean context and a written artefact to work from.

What makes the output good is the same thing that makes a good spec: it is self-contained, specific about what is in and out of scope, and honest about what is not yet known.

---

## 5. Let something else grade the work

For anything where the agent that built it is not the right judge of it, use a subagent in a fresh context. It sees the result and the criteria, not the reasoning that produced them.

This matters most for:

- **Container and Remote Control isolation** (Stages 2 and 3). The session that configured the boundary should not be the only thing attesting that the boundary holds.
- **The rebuild package being free of secrets** (Stage 7). A fresh reader is better at spotting what a familiar one skims.
- **The hooks actually blocking what they claim to** (Stage 3). Have a subagent try to get past them.

Tell the reviewer to report only gaps that affect correctness or a stated requirement. A reviewer asked to find problems will find some whether or not they exist, and chasing all of them produces defensive complexity nobody asked for.

---

## 6. Keep research out of the main context

Investigations read a lot and most of what they read is not needed afterwards. Delegate them to subagents, which report back a summary and keep their file reads out of the main window.

Scope investigations. "Investigate X" with no boundary reads hundreds of files and fills the context; "find out whether Y is true, look in these places" does not.

---

## 7. Prefer a CLI over prose, and a hook over a rule

Two patterns from the guidance that shape this build's design rather than just its process.

**CLI tools are the most context-efficient way to interact with anything external.** This is why the build produces `bin/aios` rather than teaching the agent a set of file conventions to follow by hand. One command with `--help` costs less context than a page of instructions, cannot drift from the implementation, and is reusable by scheduled runs and any future app. The same argument applies to anything this system needs to do repeatedly: write the script, then the instruction is the script's name.

**Hooks are deterministic; instructions in CLAUDE.md are advisory.** Anything that must happen every time with no exceptions belongs in a hook. This is the documented reason the security model in `ARCHITECTURE.md` puts enforcement in hooks rather than in prompts, and it is why a permission prompt is not a security control against someone holding the account.

---

## 8. Keep CLAUDE.md short, and use skills for the rest

CLAUDE.md loads on every session. The test for every line is: **would removing this cause a mistake?** If not, cut it. A bloated CLAUDE.md is not a thorough one; it is one where the important rules get lost among the unimportant ones.

Symptoms that it is too long: an instruction that keeps being ignored despite being written down, or questions being asked that the file already answers.

What belongs there: the persona and stance, the hard boundaries, the rituals in summary, commands that cannot be guessed, and gotchas. What does not: anything derivable by reading the directory, standard practice, long explanations, or detail that is only relevant sometimes.

Detail that is only relevant sometimes belongs in a **skill**, which loads on demand. The rituals are the obvious candidates: `weekly-review`, `bottleneck-analysis`, `self-sabotage-check`, `audit`. Each is a `SKILL.md` that costs a line of description at session start and nothing more until it is used. Use `disable-model-invocation: true` for anything with side effects that should only run when asked.

---

## 9. Scope tools on unattended runs

Scheduled runs (Stage 6) execute with nobody watching. Restrict them to the tools they need rather than running with everything available, and prefer `claude -p` with an explicit tool allowlist. A run that only needs to read `checkins/` and write one file should not be able to do more than that.

This is defence in depth against the agent doing something unexpected, not a statement about likelihood. It costs one flag.

---

## 10. Delegate, don't dictate

The documentation's own framing, and the reason `BUILD.md` is written as goals rather than steps:

> Think of delegating to a capable colleague. Give context and direction, then trust Claude to figure out the details.

Corollaries worth stating, because they cut both ways:

- Give the symptom, the likely location and what fixed looks like, rather than a sequence of commands.
- Point at sources rather than describing them. `@` a file, paste the error, give the URL.
- Reference an existing pattern when one exists. "Follow the shape of X" beats a description of X.
- Fix root causes. An error suppressed is not an error fixed, and a check weakened to pass is worse than a check failing.
- Interrupt early. Correcting quickly beats letting a wrong approach run to completion.

---

## 11. Karpathy, for the same reason

Karpathy's current framing points the same way as the guidance above. His move away from what he called vibe coding is towards the human writing rigorous specifications, defining architecture and guardrails, and then verifying output at the scale being delegated, rather than reading generated code and accepting it because it looks plausible. His position that you remain responsible for your software regardless of how it was produced is the same argument as this system's autonomy ladder.

The practical consequence for this build is the one already stated in Section 1: the bottleneck is not how much an agent can produce, it is how much of that output can be verified. Everything in `verify/` exists to move that limit.

Sources worth reading directly rather than through summaries: [Claude Code best practices](https://code.claude.com/docs/en/best-practices), [How Claude Code works](https://code.claude.com/docs/en/how-claude-code-works), and Karpathy's own writing rather than the considerable volume of secondary commentary on it.

---

## 12. What this document does not do

It does not tell the agent which tools to call, what order to read files in, or how to configure a firewall. That is what it is for, and dictating it produces worse results than describing the outcome and letting it work.

If something here turns out to be wrong in practice, it is wrong. Say so and change it.
