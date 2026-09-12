# R2 - Privacy, model routing and cost

Loaded when configuring the lanes, changing routing, or asking where the money and the time go.

---

## 1. Data classes, and where each may travel

The only classification that matters is where something is allowed to go. Four classes, and every
file is in exactly one by virtue of **where it lives**, never by a judgement made per request.

| Class | Lives in | May reach Anthropic | May reach a free tier | In the backup |
|---|---|---|---|---|
| **Ground truth and coaching** | `goals/ daily/ review/ reference/` | Yes, as excerpts | **Never** | Yes, encrypted |
| **Operational** | `ops/` | Metadata only | Never | Yes, encrypted |
| **Utility** | `utility/` | Yes | **Yes, that is the point** | Yes, encrypted |
| **Quarantined** | `untrusted-external/` | Yes, confined | Yes | Yes, encrypted |
| **Secrets** | `secrets/` | **Never** | Never | Separately, not in the restic repo |

**Why location and not content.** Sensitivity is a property of sentences, not files. A check-in
that says "couldn't focus, stressed about the mortgage" is financial, personal, and sits in
`daily/`. Any rule requiring something to decide "is this sensitive?" per request will eventually
decide wrong, silently, and in the free-tier case that means into a provider that trains on it.
A path is not a judgement. A path can be enforced by a hook, and is (`FT.3`, `FT.4`).

---

## 2. The utility lane

### What it is for

Free capacity from other providers doing work that needs no judgement, so the Pro subscription is
spent on the work that does. Shopping list. To-do list. "What temperature for chicken thighs."
"Convert 3 cups to grams." Turning a spoken sentence into three list items.

### How it is confined

Three mechanisms, none of which is a judgement:

1. **The router runs on the host**, not in the container, so the container never holds the
   credential. A compromise of the container reaches the data mount and does not reach this key.
2. **`AIOS_LANE=utility`** makes the write-guard confine every read and write to `utility/` and
   `untrusted-external/`. Everything else does not exist to it.
3. **The router refuses a prompt that even names the coaching tree**, before any network call.

`FT.1`-`FT.6` check all of it, including that the lane can **still write its own directory**,
because a guard that refuses everything is as broken as one that refuses nothing.

### The honest part

**A to-do list is a portrait of a life over time.** Weeks of shopping lists and errands describe a
household: how many people, what they eat, when they travel, what they are dealing with. Free
tiers generally train on what they receive, and what is sent cannot be recalled.

So: the lane is **opt-in per item**, not a default destination. The coaching layer never writes
into `utility/` (`FT.6`), which means nothing arrives there as a side effect of a conversation
about your goals. Putting something in the lane is a thing the user does deliberately.

If that trade stops feeling worth it, the lane is removable in one step: stop invoking the
router. Nothing else in the design depends on it.

### Before relying on a provider

Free tiers change their terms, their models and their retention faster than anything else here.
So the provider call is deliberately a single replaceable function in `bin/utility-router.sh`,
and before relying on one, check three things and write the date next to the answer: whether the
free tier still exists at a useful quota, whether inputs are used for training (assume yes unless
the terms say otherwise in writing), and whether the endpoint or model name has changed. That
last one is what breaks silently.

**Open-weight models reached through someone else's free API are a third party like any other.**
The licence on the weights says nothing about what the host does with your prompts.

### Local models: not now, and why

A 4 GB VPS has no room for a useful model alongside the container, restic and everything else.
Haiku already does mechanical work inside the subscription at no marginal cost. Adding one buys
independence the system does not currently need, at the cost of memory it does not have.

**Trigger:** either repeated usage-limit failures in the run records, not a hunch, or a genuine
requirement that some category of data never leave the machine. The second is the stronger
reason. Either way it needs a bigger VPS, which is a budget conversation before it is a technical
one. Full specification in `R7-after-v1.md`.

---

## 3. Model routing

Route by rule, in code. `--model` on the invocation is the mechanism. **There is no router**,
because a process that calls an API to choose a model bills per token outside the subscription,
adds latency and a credential, and puts a failure mode in front of every request.

| Work | Route |
|---|---|
| Fully determined by its input | **A script. No model at all** |
| Low-stakes utility | Free tier, utility lane |
| Classification, extraction, parsing prose into fields | `haiku` |
| Check-in conversation, filing, weekly review first pass | `sonnet` |
| Escalation only | `opus` |

**Some routines make no model call whatsoever**, and that is a design position rather than an
omission: the change ledger is `sha256sum`, `sort` and `diff`; the backup is `restic`; the
security observation is `ss`, `getent` and `diff`; the health check is the harness. A model in a
deterministic job buys nothing and adds cost, latency and a failure mode. If a routine's output
is fully determined by its input, it gets no `--model` because it makes no call.

### Escalate on evidence, never on self-assessment

A model that is not capable enough for a task is not reliable at noticing it. The failure mode is
a confident wrong answer, not a request for help.

Escalate when, and only when: a check failed; output failed schema validation; the model hedged;
a retry already failed; or the input exceeds the window.

**Trigger three is a heuristic and is labelled one.** Hedging is detected by pattern-matching for
markers like "I'm not certain" and "it's difficult to say". It catches the polite failure and
misses confident nonsense entirely, which is the case that matters most. The other four are
mechanical and reliable.

### Budget and degradation

At most **two escalations per run**, and exhausting the budget is a recorded failure rather than a
silent continuation. A **model-specific** limit is not a failed run: fall back to `sonnet`, set
`"degraded": true`, and the review names it, because a degraded review should say so. A
**session or weekly** limit **is** a failed run: there is nothing to fall back to, it exits
non-zero, and the freshness checks catch it.

---

## 4. Cost and time efficiency on a fixed plan

Pro plus a 10 AUD VPS is a hard constraint. The design fits inside it or it is the wrong design.
With no per-token bill, "cost" means **the shared usage limit**, which is the real scarce
resource and is shared with the user's own daily Claude use.

Six levers, in order of how much they actually return:

**1. Do not make the call.** By far the largest. Every routine that is a script is a routine that
costs nothing and cannot be starved. Before adding a model call anywhere, ask whether the output
is fully determined by the input.

**2. Send the right context, not the maximum context.** Retrieve excerpts; never dump a
directory. This serves privacy and reasoning quality at the same time, because quality degrades
well before the nominal window limit and important information gets buried by low-value
information long before anything overflows.

**3. Order the prompt for caching.** Stable content first, volatile content last. One byte
changing early invalidates everything after it, so a prompt that leads with today's date and then
includes the goals is a prompt that caches nothing.

**4. Compile once.** Anything summarised should be summarised once and the result reused, rather
than re-read from source every week. This is both the cost lever and the context-rot defence.

**5. Route down.** Haiku for mechanical language work, the free tier for utility work, Sonnet as
the workhorse, Opus only on the five triggers above.

**6. Keep scheduled work small.** The nightly routines are deliberately tiny. A heavy scheduled
workload competes with the user's own afternoon on the phone, and the run that loses is the one
nobody was watching.

### What the Pro constraint actually costs

Said plainly, because a blueprint that only lists benefits is not honest:

- **No large-scale summarisation.** Anything that would chew a weekly allowance is not available,
  which is part of why bulk research is a short weekly scan rather than a firehose.
- **The system can be starved by its owner.** A heavy afternoon on the phone can cost that night's
  review. This is made visible rather than prevented, and a starved run reads as a failure.
- **No parallel or continuous agents.** One routine at a time, each bounded, each locked.
- **Opus is rationed**, so the deepest reasoning is reserved for evidence-triggered escalation
  rather than being the default for the weekly review.

Every one of these is a real limitation. The design's answer is that a system which quietly
overran its budget would be worse, because the user would find out from a bill or a lockout
rather than from a run record.

### Measuring it

The audit records, per week: how many routines ran, how many made a model call, how many
escalated, how many were degraded, and how many failed with `error_class: usage_limit`. That last
count is the one that matters. A rising trend is the trigger for either reducing scheduled work or
having the budget conversation, and it is evidence rather than a feeling.

---

## 5. Data minimisation as a standing rule

Every model call, whichever provider: what is the minimum information required to complete this
task? Retrieve excerpts rather than stores. Never pass a whole directory because it is easier.
**Access is not permission**: being able to read a file does not mean it may be sent externally,
passed to another component, or included in a prompt.

And the rule that outranks all of it, because it is the only one with no retrospective fix:
**if something must never reach a backup or a provider, it must never be written at all.**
