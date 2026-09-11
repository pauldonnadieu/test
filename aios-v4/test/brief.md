You are building a personal AI operating system on this machine.

The complete specification is in `./aios/`. Start with `aios/README.md`, which names the
reading order, then work through `aios/02-build.md` stage by stage.

Build it. Work through as many stages as you can.

Rules for this run:

1. **Nobody is available to answer questions.** When something is ambiguous, choose the most
   reasonable interpretation, proceed, and append one line to `ASSUMPTIONS.md` in this
   directory: what was ambiguous, what you chose, and which document should have told you.
   One line per assumption. This file matters more than the build.

2. **Some stages need a person and cannot be completed here.** `aios/HUMAN-TASKS.md` lists
   them. When one blocks you, do every part of the stage that does not depend on it, write what
   is blocked and why to `blocked.md` in this directory, and move on. **Never invent a
   credential, fabricate an attestation, or write a plausible-looking claim about the user's
   life.** A fabricated goal file reads exactly like a real one six months later.

3. **This sandbox is not a VPS.** There is no Docker daemon, no cron, no ufw, no Tailscale.
   Where a stage needs something absent, substitute the closest honest equivalent that this
   machine can actually do, record the substitution in `SUBSTITUTIONS.md`, and continue to the
   next stage. Two substitutions are already decided for you:
   - The container's non-root user is a **real unix user** named `aios`. It already exists.
     The privilege boundary between it and root is real, so build it for real.
   - The backup destination is a **local restic repository** at `/srv/aios/repo`, not Google
     Drive. `restic` may need installing.

   Do not fake anything you cannot do. A stage honestly skipped is worth more than a stage
   pretended.

4. **Verify as you go.** `aios/checks/run-all.sh` is the scoring harness. Configure it
   (`aios/checks/config.env.example` is the template) and run it. A stage is done when its
   check passes. Checks specified in `aios/checks/NEW-CHECKS.md` do not exist yet; write them,
   and prove each one by breaking the thing it tests before trusting it to pass.

5. When you stop, write `HANDOVER.md`: which stages are done, which are not, what is blocked on
   a human, and what you would do next.
