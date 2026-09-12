# Human tasks

Everything in this build that Claude Code cannot do for you, in the order the build needs it.

Claude Code should read this file, work out which items are still outstanding, and stop and ask
at the point where one blocks it rather than inventing a way around. Every item here exists
because it needs a browser, a credit card, a phone, a second machine, or a person who can
truthfully attest to something.

**How to use this with Claude Code.** Hand it the whole `aios/` folder and tell it to build.
When it reaches a stage that depends on an item below, it should say which item, what it needs
from you, and wait. If you are not there, it records the block and moves to the next stage that
is not blocked, per the unattended rules in `core/02-build.md`.

---

## Before anything (about 45 minutes, about 15 AUD to start)

| # | What | Why | Where |
|---|---|---|---|
| H1 | Create a Hetzner Cloud account, add a payment method, create a project | The VPS. Nothing starts without it | console.hetzner.cloud |
| H2 | Create the server: CX or CPX class, about 2 vCPU / 4 GB, EU region, Ubuntu LTS | The machine these documents assume. EU is for jurisdiction, not latency | Hetzner console |
| H3 | Add your SSH public key during creation, not after | A box created without one gets a root password by email, which is a worse start | Hetzner console |
| H4 | Record the Hetzner console password in the password manager | This is the break-glass path when Tailscale itself is the problem | Password manager |
| H5 | Create a Tailscale account and note the tailnet name | Administration and break-glass. No inbound port on the VPS | tailscale.com |
| H6 | Confirm your timezone, in `Region/City` form | Every schedule in this build is local time. A fresh box is UTC, so an evening check-in arrives at breakfast | Tell Claude Code |

**Decide before H2:** if you are outside the EU, the EU region costs you 250 to 300 ms of
latency on every Tailscale hop and a slower backup. It buys you a privacy jurisdiction. Say
which you want; the build takes either.

---

## Before stage 0, the attestations (about 30 minutes)

These five are the security properties no check on any machine can verify. Claude Code writes
the file with every entry marked `UNATTESTED`; only you can fill them in, and a fabricated
attestation is worse than a missing one because a missing one is visible.

| # | What | Why it matters this much |
|---|---|---|
| H7 | **Turn OFF "use my data to improve Claude"** at claude.ai/settings/data-privacy-controls | With it on, consumer transcript retention is 5 years. With it off, 30 days. Highest-leverage single setting in the build |
| H8 | Put a unique strong password and a **hardware-backed second factor** on the Anthropic account | This account is a path to the container and the data mount. See `core/01-architecture.md` section 6 |
| H9 | Second factor on the Google account holding the backup | It holds ciphertext, but an attacker who can delete it can still destroy your history |
| H10 | Second factor on the **Hetzner** account | It can destroy the machine and read the console |
| H11 | Generate the restic password, store it in the password manager **and** as an offline copy that survives the password manager | Lose both and every snapshot is permanently unreadable. This is the design working, not failing |
| H11b | Write the four kill-switch layers somewhere reachable from your phone **without the AIOS**, and attest that you have | A kill switch you can only reach through the thing you are trying to stop is not a kill switch. `reference/R3-recovery.md` section 1 |

The offline copy is a real decision, not a formality. Printed and in a drawer at a different
address is fine. In the same password manager under a different name is not an offline copy.

---

## During stage 1, the host (about 1 hour, and one anxious moment)

| # | What | Why you and not Claude Code |
|---|---|---|
| H12 | Approve the Tailscale device when the VPS joins | Tailscale auth needs a browser login you hold |
| H13 | **Confirm you can reach the box on its Tailscale address before the public door closes** | This is the moment that goes wrong. Move your session to the tailnet address and use it, then remove public SSH |
| H14 | Configure the Hetzner Cloud Firewall to deny inbound | Second layer, configured independently of UFW so the two fail independently. Console only |
| H15 | **Use the Hetzner rescue console once, deliberately, while nothing is wrong** | Rehearse the break-glass path before you need it at 11pm. Ten minutes now, an hour saved later |

---

## During stage 2, the container (about 20 minutes)

| # | What | Why |
|---|---|---|
| H16 | Run `claude` interactively inside the container once and complete the OAuth login | The subscription credential cannot be obtained headlessly. This needs a real terminal, once |
| H17 | After H16, destroy the container and recreate it, and confirm **no second login is needed** | If it asks again, the credential is not on a persisted mount and the container is not disposable. This is the likeliest thing to break the whole build |

---

## During stage 10, the free-tier lane (about 15 minutes, optional)

| # | What | Why |
|---|---|---|
| H18a | Decide whether you want the utility lane at all, after reading `reference/R2-privacy-routing.md` | It puts your to-do and shopping lists through a provider that trains on them. The document is honest that a to-do list is a portrait of a life over time |
| H18b | If yes: create the free-tier account, generate a key, and put it in `secrets/free-tier-key` on the **host** | The container never holds it. That is what limits what a container compromise reaches |
| H18c | Check the free tier's current terms and quota, and write the date next to your note | Free tiers change terms, models and endpoints faster than anything else here, and the endpoint change is the one that breaks silently |

The lane is entirely optional. Skipping it costs you nothing except some Pro allowance spent on
shopping lists, and `FT.*` will report SKIP rather than failing if the lane is not configured.

---

## During stage 6, backup (about 30 minutes)

| # | What | Why |
|---|---|---|
| H18 | Complete the rclone OAuth flow for Google Drive | Browser login. Claude Code can run `rclone config` up to the point where it hands you a URL |
| H19 | Confirm the restic repository initialised with the password from H11 and not one generated on the box | A password that only exists on the machine dies with the machine |

---

## Stage 5, the intake (about 45 minutes, and the highest-value item here)

| # | What | Why |
|---|---|---|
| H20 | Sit down and answer the intake interview properly | Everything downstream reasons over this. A generic picture produces generic coaching, which is worse than none because it wastes the attention the system exists to protect |

Be specific where it hurts. "Busy" is not a constraint. "No discretionary time between 6am and
8pm on weekdays, and two office days a week with a 50-minute commute each way" is a constraint,
and it is the difference between advice you follow and advice you resent.

Cover what has repeatedly failed and roughly how many times. That count is the single most
useful thing you can hand the system, and it is the thing every abandoned productivity system
never asked for.

**You are done when at least one thing in the written result mildly surprises you**: true, but
not previously articulated. If nothing does, the interview was too shallow, and it is worth
another twenty minutes now rather than six months of shallow reviews.

---

## Stage 11, handover (about 30 minutes)

| # | What | Why |
|---|---|---|
| H21 | Install Tailscale and the Claude app on your phone, and the password manager if it is not there | The phone is the interface |
| H22 | Complete one real check-in from the phone, end to end | Proves the actual daily path, not a simulation of it |
| H23 | Ask it one real question from the phone | Proves the interactive path |
| H24 | Walk the break-glass path yourself: Tailscale SSH from a laptop, `docker restart`, read `ops/runs/*.jsonl` | So the first time you do it is not the first time you need it |
| H25 | Use kill-switch layers 1 and 3 once each, deliberately, and watch a routine stop | You wrote them down at H11b. This is the rehearsal, and `reference/R3-recovery.md` section 1 is the reference |

---

## Stage 12, the acceptance test (about 2 hours, about 1 AUD)

| # | What | Why |
|---|---|---|
| H25b | Read `reference/R6-worked-example.md` and then read your own first weekly review next to it | The harness checks shape, never judgement. This is the only way to find out whether what it writes is any good |
| H26 | Provide an outside vantage point for the firewall probe: another machine you control, a second throwaway VPS, or your phone on mobile data with wifi off | A box cannot honestly test its own firewall. A tailnet device is not a valid vantage point |
| H27 | Reboot the machine and confirm everything comes back with no human intervention | The classic silent failure. Do it before real data goes in |
| H28 | **Perform the recovery drill yourself**, on a second fresh VPS, using only the rebuild package and the offline key | The scenario is the VPS being gone. What matters is whether you can recover it, and no automated check can test that |
| H29 | Write down how long H28 took | That number is what you are actually buying with this design |

H28 is the acceptance test. Everything else checks that a running system is healthy; this
checks the claim the whole backup design rests on. If you had to look at the old box for
anything, you tested copying, not recovery.

---

## Recurring, forever

| When | What |
|---|---|
| Daily | The check-in. Thirty seconds. Everything else depends on it |
| Weekly | Read the review. That is the whole point |
| Monthly | Approve or reject anything in `ops/proposals/`. At most one adoption per month |
| Quarterly | The restore drill again (H28), and **read the offline key to confirm it is still there and still legible** |
| Quarterly | The tier-3 read: open `CLAUDE.md` and one weekly review cold and ask whether they are any good. No check can answer this |
| Annually | Re-verify the watchlist in `reference/R4-currency.md` still points at things that exist, and write the date |
| Annually | Re-run the intake as a conversation. A year of check-ins is better material than you had the first time |
| Annually | Re-attest H7 to H11b. The check fails on an entry older than 12 months, by design |

---

## What this costs

| Item | Cost |
|---|---|
| VPS | about 10 AUD/month |
| Claude Pro | about 35 AUD/month |
| Tailscale | free at this scale |
| Google Drive | free tier is enough for years of this data |
| Recovery drill, per run | a few cents of second VPS, four times a year |
| **Running total** | **about 45 AUD/month** |

Everything in `reference/R7-after-v1.md` is outside this. The Apple Developer Program, at 99 USD a year,
is roughly a third of the annual running cost of the entire system, which is why the phone app
is a real decision and not a footnote.

---

## The rule Claude Code follows when you are not here

If an item above is outstanding and a stage needs it:

1. Do every part of the stage that does not depend on it.
2. Write what is blocked, which item blocks it, and exactly what is needed, to
   `ops/blocked.md`.
3. Move to the next stage that is not blocked.
4. Never invent a credential, never fabricate an attestation, never write a plausible-looking
   claim on the user's behalf, and never work around a blocked item by weakening a control.

A stage honestly blocked is worth more than a stage pretended.
