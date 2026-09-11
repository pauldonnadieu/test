---
name: stage
description: Load the context and goal condition for one stage of the AIOS build
disable-model-invocation: true
---

Work stage $ARGUMENTS of the AIOS build.

1. Read `docs/BUILD.md` and find the stage numbered $ARGUMENTS. Read only that stage plus the "How to work" section at the top; the rest is not needed yet.
2. Read `docs/WORKING.md` if this is the first stage of the session.
3. Read the sections of `docs/ARCHITECTURE.md` that the stage references.
4. State back, in a few lines: the goal, the definition of done, and the constraints. If anything is ambiguous or looks wrong given what you can see, say so now rather than after building.
5. Print the stage's **Goal condition** block verbatim so the user can paste it into `/goal`, and say that running it in auto mode will let the turns proceed unattended.
6. Then work the stage. Write `verify/stage$ARGUMENTS-*.sh` alongside the work, following `verify/CONTRACT.md`, and iterate until it prints a full score.

Do not begin another stage in this session. When this one passes, say so, show the score line as evidence, and stop.
