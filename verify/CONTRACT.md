# Verification contract

Every stage of the build produces a script here. The scripts are the definition of done and, afterwards, the security regression suite.

## Why a score and not just pass/fail

A binary gate tells an agent it failed. A score tells it whether it is getting closer. `SCORE 11/13` on one turn and `SCORE 12/13` on the next is a gradient the loop can work against; `FAIL` twice in a row is not.

The score also survives the transcript. The `/goal` evaluator cannot run commands or read files, so it judges only what has been surfaced in the conversation. A printed `SCORE` line is something it can read. A silent exit code is not.

## Output format

Every script prints one line per check and ends with a score:

```
[PASS] ssh-no-password                 SSH rejects password authentication
[FAIL] ufw-default-deny                UFW default-denies inbound
       Default: allow (incoming), allow (outgoing)
[SKIP] external-scan                   run nmap from another machine

SCORE 6/8 stage1-host
FAILED: ufw-default-deny
SKIPPED: external-scan
```

Rules:

- **Exit 0 only when every check ran and every check passed.** A skip is not a pass.
- **Always print the `SCORE` line**, pass or fail. It is the machine-readable result.
- **Name every failure and skip.** A count with no names cannot be acted on.
- **One check, one property.** A check that tests three things tells you little when it fails.
- **Check the property, not the configuration that should produce it.** `ss -ltn` showing nothing on a public interface is the property. A firewall rule file containing the right text is a proxy for it, and proxies drift.

## Writing a check

```bash
source "$(dirname "$0")/lib.sh"

check some-name "what this proves" <<'TEST'
# any shell; exit 0 means pass
command-that-should-succeed
TEST

summary stage1-host
```

`skip name reason` records a check that could not run here. Skips make the script exit non-zero on purpose: an unrun check is an unknown, and an unknown is not a pass.

## Negative checks matter more than positive ones

The most valuable checks prove that something is *not* possible. A check that a firewall is configured is weak; a check that a connection is actually refused is strong. Examples worth writing:

- A planted fake secret cannot be committed.
- A Remote Control session cannot read `/etc/aios/secrets.env`.
- The container cannot reach the Docker socket or become host root.
- A write to `policy/` after reading `raw/untrusted/` is blocked by the hook.
- A verb outside the CLI allowlist is refused.

`stage1-host.sh` has a worked example of this shape: it plants a fake AWS key and an API-key-shaped string, then asserts the commit **fails**. If secret scanning ever silently breaks, that check catches it.

## What not to do

- Do not weaken a check so a stage passes. That is the one move never available; the check is the contract.
- Do not delete a check because it is inconvenient. Fix the property or record why the check was wrong.
- Do not write a check that passes when the thing it tests is absent. `grep -q x file || true` passes on a missing file.
