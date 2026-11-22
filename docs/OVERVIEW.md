# The repo is the memory

*What this template is, why it is shaped the way it is, and what real projects
showed about it. Read this first; the [README](../README.md) covers setup and
commands, [PLAYBOOK.md](PLAYBOOK.md) the full arc, [USAGE.md](USAGE.md) the
daily loop.*

---

## The problem

You start a side project with an agent. The first evening goes better than the
last month did. Four days later you come back and the agent has no idea what you
were doing, and neither do you. By day ten the codebase has three patterns for
the same thing, because nine sessions each made a reasonable local choice.

The agent is not the weak part. The failure is structural:

- **Every session starts cold.** The agent's context ends when the session does.
- **You are the only continuity**, and a side project gets part-time attention.
- So the repo fills up with **decisions nobody wrote down**, every change costs
  more than the last, and eventually you stop opening it.

This is a memory problem, not a capability problem. A better model makes each
session better. It does nothing about the gap *between* sessions.

## The idea

If the agent forgets everything between sessions, the repo has to remember. The
code is not enough: code records *what*, never *why*.

```
Repo        the app — persists forever, accumulates the "why"
 └─ Project     a wave of work: "MVP", "v2", "redesign"
     └─ Stage       a coherent chunk (2–5 per project)
         └─ Spec        one implementable task
              └─ Cycle      Frame → Design → Build → Verify → Ship
```

**Projects end; the repo doesn't.** Architecture, constraints and decisions live
at repo level, so they outlast the wave of work that produced them. Most tooling
models the sprint. Very little models what the sprint leaves behind.

Each layer answers a question you would ask anyway:

| Layer | The question | Who asks it |
|---|---|---|
| **Project** | What wave are we on, and why now? | Anyone who asks what you're building |
| **Stage** | What coherent chunk is next? | You, on Monday morning |
| **Spec** | What's the one task, and what proves it's done? | The agent |
| **Decision** (`DEC-*`) | Why is it this way? | You, four months from now |

Everything is markdown with YAML front-matter, read and written by shell
scripts behind `just`. There is nothing else to install: no database, no
service, no `jq` or `yq`. Nothing to install means nothing to abandon.

## The cycle

| Phase | The question it answers |
|---|---|
| **Frame** | Why does this exist? What would prove it's done? |
| **Design** | What's the approach, and what did we decide? |
| **Build** | Make the failing tests pass. |
| **Verify** | Were the acceptance criteria actually met? |
| **Ship** | What did we learn, and what did it cost? |

### The rule: build and verify each get a fresh session

This is the rule that matters most, and the one people resist. *Isn't that
throwing context away?* No — it forces the context **into the spec**, where the
next session and future you can read it. And a session that designed a change
cannot review it: it already believes the code is right, because it wrote the
plan.

The template now builds this in. Design writes a `HANDOFF-NNN` for build and
another for verify (`just new-handoff`). Each goes to a fresh Claude session or
subagent, or to another tool such as Codex, Kilo Code or Cursor. The agent that
ran the cycle fills in its verdict, which model ran, and what it cost, and
`just handback-sync` copies that into the spec. The orchestrator never estimates
a cycle it didn't run. (The older single-session variant, `claude-only`, is
deprecated — see [DEC-015](decisions/DEC-015-one-variant-claude-plus-agents.md).)

One tell that the rule was skipped: a build reflection that says *"nothing was
unclear."* That is what design and build sharing a session looks like.

### Claude is the UI; the commands are the API

You don't type most of the commands. You work in a conversation — *"what's
ready?"*, *"start the next spec"*, *"land that spike"* — and the agent runs
them. The conventions file (`AGENTS.md`) is written to the agent, not to you,
and `--json` on every read command is a versioned contract for exactly that
reason ([DEC-001](decisions/DEC-001-interface-contract.md)).

That creates a new way to fail: **agent-graded homework.** The agent proposes
the work, builds it, reviews it, writes the reflection and concludes it went
well. Every artifact is present, every gate is green, and the record is fiction.
So four decisions stay with you, and they are the cheap ones:

1. **Go or kill.** The agent leans toward "this is viable, here's a plan."
2. **Which lane** a change belongs in (below).
3. **Whether to accept a rejection** from verify.
4. **Whether a reflection is honest.**

The agent does the work; you keep the judgment. A useful check on yourself:
*when did you last tell it no?*

## Three lanes, routed by stakes

The full cycle pays off on high-stakes work: hardening, releases, catching a
licence problem before it reaches the tree. On a three-line fix it is pure
ceremony, you will resent it, and resenting a process is how people drop it.
**Value tracks stakes, not size.** So there are three lanes:

| Lane | Cycle | For |
|---|---|---|
| **Spec** | frame → design → build → verify → ship | Committed work |
| **Patch** | patch → verify → ship | A bounded fix to shipped behaviour ([DEC-003](decisions/DEC-003-patch-lane.md)) |
| **Spike** | spike → land | Exploring before you know the shape, including vibe-coding sessions ([DEC-012](decisions/DEC-012-spike-lane.md)) |

The patch lane keeps the two things that prevent errors (below) and drops the
rest. If your process has one gear, it is wrong for most of your work.

## What it gives you

- **Stopping and restarting costs nothing.** Come back after two weeks, run
  `just dash`, and the repo tells you where you were. This is the benefit
  people feel first, and it is why side projects get finished.
- **The record can be queried.** `just specs-by-stage` for what shipped and
  when; `just ready` for what can be picked up now (and safely in parallel);
  `just calibration` for whether your size estimates are any good;
  `just dash signals` for what's queued to change the rules.
- **Decisions stop being re-argued.** Each `DEC-*` records the options rejected
  and an honest confidence number, and can name in advance what would make it
  wrong.
- **Progress and impact are captured as a side effect.** Every spec states the
  value it should deliver. Ship asks, in a fixed slot, *"What can a user do now
  that they couldn't before?"* — one sentence, or `none`. The agent logs that
  sentence as the impact line in a brag file
  ([DEC-010](decisions/DEC-010-accomplishment-logging-default.md)), at the one
  moment the answer is knowable, by the one party who was there. Nobody writes a
  status report; `just report` and `just release-notes` assemble it from what
  the specs already say.

## What real projects showed

The template has been used on [seven real projects](../PROJECTS.md): CLIs, a
Rust RAW-image library, an EXIF reader, a browser game. The numbers below are
from the bragfile three-project retro and the July 2026 harvest across three
projects and 121 specs; the sources are listed in the
[talk plan's fact sheet](talks/spec-driven-template.md#fact-sheet).

**The record holds up.** By the bragfile retro: 42 specs across 4 projects, 40
shipped, every stage completed in order, no drift between design and ship. Of 25
decisions, exactly one was superseded — and it was superseded by the trigger it
had written down in advance. Mean decision confidence was 0.82, with no 1.0s
anywhere, which is a sign the records are honest rather than decorative.

**Misses become visible.** bragfile's MVP brief said about two weeks; it took
about four. That is in the project's own reflection, where the next estimate
has to look at it. The process does not make you fast, especially at first. It
makes your misses legible instead of forgotten.

**Every escaped defect was operational, not logic.** Looking for defects that
got past design, build *and* verify, every one was about whether the thing
*runs*: a timezone bug that zeroed a streak counter, a release tool cutting two
tags on one commit, macOS Gatekeeper blocking a signed binary, Homebrew tap
trust, a development binary that migrated the production database, and a plugin
manifest that passed strict validation and registered zero servers. The cycle
was dense on whether the logic was right and nearly silent on whether the
software ran. The rule that came out of it: when a spec claims something about
runtime behaviour, its pre-flight must exercise that behaviour, not just
validate the shape. Release specs now carry that checklist
([DEC-006](decisions/DEC-006-release-spec-template.md)).

**Aim the first spec at something shippable.** bragfile took about three weeks
to its first ship. crustyimg's first spec was created and shipped the same day,
with the same process, because it targeted a thin end-to-end slice instead of a
foundation.

**Quality that feels untestable usually has a testable precondition.** The slot
game's brief worried that "feel" resists TDD. It then gated the mechanical
preconditions of feel in CI: contrast ratios, compositor-only animations, touch
target sizes, motion budgets.

**Two things prevented nearly all the errors:** the independent verify, and the
decision log. Everything else is scaffolding around those two.

## How the template changes

The features came from the projects, not from thinking about process. The
spec-by-stage ledger was back-ported from bragfile. The patch lane was invented
by crustyimg after a three-line fix ran the full cycle. Two projects built a
release checklist before the template had one. Build provenance started as
bragfile's guard against a dev binary touching production data.

Every ship asks whether anything should change the rules. Answers go into one
ledger, and every stage or project close must accept, reject or defer each open
item, with a trigger for deferrals. The bar for turning an observation into a
rule is **N=3 same-outcome, or N=2 paired-opposing** — three independent
occurrences of the same failure, or one confirmation by presence and one by
absence. The clearest recommendation from three projects was *don't codify
sooner.* When the template breaks its own bar (the spike lane shipped on one
data point), the decision record says so and names the trigger that will cut it
back.

Fixes reach existing projects through `just template-update`, which replaces
unedited template files and three-way merges edited ones.

## Honest limits

- **Slower per spec on low-stakes work.** That is what the patch and spike lanes
  are for. Across a project it is roughly a wash, and the project finishes.
- **The evidence is solo projects.** The design targets agents that don't share
  memory, which is structurally the same problem as people who don't share
  context, but team use is unproven.
- **Cost figures are not comparable across eras.** Projects measured tokens in
  different ways before the method was written down (v0.6.48). Each spec now
  records the `basis` of its numbers, and `just calibration` flags bands that
  mix them; older totals should not be added up.
- **Existing codebases:** write down the decisions that still constrain what you
  build next, frame the first project around what's *next*, and don't
  retro-write specs for code that already works. See
  [PLAYBOOK.md](PLAYBOOK.md) for the on-ramps.

See also [KNOWN_LIMITATIONS.md](../KNOWN_LIMITATIONS.md).

## If you only take two habits

1. **Write the decision down when you make it.** One paragraph, the options you
   rejected, an honest confidence number. Later never comes.
2. **Review in a session that didn't write the code.** Same model, same
   machine, new context. Nearly free, and the highest-yield step in the process.

If those two feel good after a month, the rest of this template is what they
grow into.
