# Harvest 2026-11-19 — reflection answers sorted by CAFE(S)

**Question:** do the build/verify reflection answers across every instance show a
recurring *kind* of context failure, using the CAFE(S) vocabulary (Houck,
Kanat-Alexander, Kalliamvakou, Storey, Forsgren — "CAFE(S): Your Agent Is Only
As Good As Its Context", ACM Queue, Sept 2026)? If one dimension dominates at
N≥3, that is the case for a template change; if not, nothing gets built.

**CAFE(S) in one line each:** **C**larity — can it be read only one way?
**A**ctionability — goal, constraints and "done" stated? **F**idelity — is it
true and current? **E**fficiency — signal over noise? **(S)**ecurity — should
the agent have it at all?

## Method

- **Corpus:** `origin/main` of all 10 repos in the warehouse's `instances.txt`
  (bragfile000, crustyimg, zany, rspeed, standup, skillport, irradiance,
  diamond-exif, grebe, onyx), fetched 2026-11-19. Read via `git show`; no
  working tree touched. Excluded: `_templates/`, `prompts/`, `docs/`,
  `tests/fixtures/` (standup carries copies of other instances' specs), and
  nested `.claude/worktrees/`.
- **Answers taken:** the two reflection questions present in both variants —
  *"What was unclear in the spec/handoff that slowed you down?"* (`unclear`)
  and *"Was there a constraint or decision that should have been listed but
  wasn't?"* (`missing`). claude-only instances answer them in the spec,
  plus-agents instances in the handoff.
- **Volume:** 1,106 answers extracted; 32 empty/placeholder dropped; 27 short
  "Nothing/None" answers auto-labelled `none`; **1,047 classified** by four
  parallel Sonnet agents against a fixed rubric (primary + secondary dimension,
  a context-smell name, and the artifact at fault). Extra labels beyond CAFE:
  `tooling` (template commands/process) and `other` (environment). Spot-checked
  16 random labels by hand — all defensible.
- **Caveats:** labels are model judgements, one pass, no second rater. Many
  "problem" answers are minor ("very little; one small thing…") — this counts
  *occurrence*, not severity. Self-reported reflections only see what the agent
  noticed (see finding 3).

## Results

**610 of 1,074 answers (57%) report a real context problem.**

| Primary dimension | Answers | Share of problems |
|---|---:|---:|
| Actionability | 275 | 45% |
| Fidelity | 175 | 29% |
| Clarity | 110 | 18% |
| Other (environment) | 35 | 6% |
| Tooling | 13 | 2% |
| Efficiency | 2 | 0.3% |
| Security | 0 | 0% |

Split by question, which matters (finding 1):

| Question | none | fidelity | actionability | clarity | other/tooling |
|---|---:|---:|---:|---:|---:|
| `unclear` | 193 | **141** | 97 | 89 | 31 |
| `missing` | 271 | 34 | **178** | 21 | 19 |

Artifact at fault: spec 385, handoff 101, decision 38, toolchain-brief 21,
template-tooling 16, codebase 14, constraints 12, brief 6, AGENTS.md 4.

Top smells: missing-constraint 183, stale-guidance 76, unstated-default 66,
specification-ambiguity 54, contradictory-context 53, wrong-claim /
confident-hallucination / false-assumption 63 combined.

Actionability is the top dimension in 9 of 10 instances (skillport: fidelity);
fidelity or clarity is second everywhere. diamond-exif is the outlier with
`other` (sandbox/environment) in its top three. Problem
rates range 24% (skillport) to 89% (diamond-exif).

## Findings

1. **The "unclear" question mostly harvests fidelity, not clarity.** Asked what
   was *unclear*, agents most often report something that was *wrong*: a spec
   asserting a failure mode that doesn't happen, a toolchain brief claiming a
   component is installed when it isn't, a handoff framing work as greenfield
   after the extraction already shipped. Clarity is third. The question's
   wording and what it collects have drifted apart — a reader of these answers
   (`weekly-review`, a harvest) currently can't tell "ambiguous" from "false".

2. **Fidelity failures are mostly design-time claims nobody checked against
   the code.** ~46 answers across 6 instances (rough regex count) say a probe
   or grep at design time would have caught it. This is DEC-004 rule 1 ("verify
   claims against data") failing in the *design* cycle, not a new principle.
   crustyimg answers repeatedly credit "probe-verified" design notes for a
   clean build — the counterexample that shows the fix works when used.

3. **Efficiency and security are invisible to self-report (2 and 0).** This is
   not evidence the template is efficient or secure. An agent drowning in a
   39 KB `AGENTS.md` doesn't experience it as "unclear" — it just pays for it,
   which is exactly the paper's *Lost in the Middle* point. Those two dimensions
   have to be measured from data the template already has (`cost.*` tokens,
   rework) or from review, never from the reflection. **Do not add
   efficiency/security to a reflection vocabulary expecting signal.**

4. **The `missing` question works as designed — it's an actionability
   detector.** 178 of its 252 problem answers are missing-constraint /
   unstated-default. Recurring sub-themes: a test seam or file not named in
   Inputs; a rule from a DEC not repeated where it bites; behavior required on
   every feature leg / accumulation point but stated once.

5. **Candidate recurring patterns (each N≥3, rough regex counts — confirm
   before acting):**
   - *Toolchain brief gaps or wrong claims* — 21 answers, 19 files, 4
     instances (diamond-exif 9, irradiance 7, crustyimg 4, bragfile 1). The
     toolchain brief is the shared artifact with the highest fidelity-failure
     rate per word. Matches the paper's "every shared context source needs an
     owner and a review cadence".
   - *Sandbox/shell-guard friction not documented* — 19 answers, 3 instances,
     but 14 are diamond-exif. Instance-local; belongs in its toolchain brief,
     not the template.
   - *Handoff stale at build time* (PR already merged, worktree cut before the
     handoff landed, HEAD moved) — 8 answers, 3 instances (irradiance 6, grebe,
     onyx). A handoff is written at time T and read at T+n with no check that
     its premises still hold.

6. **Outcome join is too thin to conclude anything.** Only ~100 specs carry the
   defect-catch word. Of 10 specs whose reflections were all clean, 9 had no
   defect; of 59 with a fidelity complaint, 21 had none. Suggestive, n too
   small. Problem rate also *rises* over each instance's life (crustyimg
   50%→78%, irradiance 55%→74%) — more likely more candid reflections
   (weekly-review flags "nothing was unclear" as suspicious) than worse context.
   Can't separate the two from this data.

## What this supports

| Proposal | CAFE | Evidence | Bar met? |
|---|---|---|---|
| Add a fixed one-word CAFE line (`clarity \| actionability \| fidelity \| none`) to the build reflection, like the defect-catch word, and ship its reader in the same change | C/F | Finding 1, 1,047 answers, all 10 instances | **Built in v0.6.53** — Q4 + `just dash context` |
| Design-cycle "probe, don't assert" rule: any claim about code/tool behavior in a spec's Notes/Inputs cites the command that verified it | F | Finding 2, ~46 answers, 6 instances | **Yes** — confirm count by hand first |
| `reviewed_at` on `guidance/toolchain-brief.md` + advisory staleness line in `weekly-review` | F | Finding 5, 19 files, 4 instances | **Yes**, warn-only |
| Handoff records `base_sha`; `handback-sync`/build start warns when the base moved or a referenced PR merged | F | Finding 5, 8 answers, 3 instances | Borderline (irradiance-heavy) |
| Measure efficiency from `cost.*` (tokens per AC, per spec size) rather than reflection | E | Finding 3 (absence) | Measurement, not a convention |

Not supported: anything security-related (zero signal either way), or a
general "context review" ritual — the corpus points at specific artifacts
(spec claims, toolchain brief, handoff freshness), not context in general.

Raw extraction and labels: kept out of the repo (instance text). Reproduce
with the warehouse instance list and the rubric above.
