# Roadmap — spec-driven-template's own direction

The template's forward-looking backlog: improvements to **the template itself**
(distinct from ideas for apps *built with* it). Consolidates what was scattered
across `docs/decisions/`, `CHANGELOG.md`, and the dogfood harvests.

**Discipline (non-negotiable):** nothing here is a commitment. Priority is driven
by the **next dogfood harvest**, not by this list — codify a lesson only once it
recurs (N=3 same-outcome / N=2 paired-opposing). "Don't push it to codify sooner."
Full ranked detail + evidence lives in
[`docs/harvests/2026-07-06-three-project-dogfood-harvest.md`](harvests/2026-07-06-three-project-dogfood-harvest.md).

## Proposed — awaiting a real project to validate

- **[DEC-009](decisions/DEC-009-business-value-metrics.md) — measurable value +
  time-to-value.** Spine (outcome targets on the stage) is likely right, but the
  **metric-derivation aid** must be validated at a real project's *frame* (deriving
  the target metric live), **and it must handle goal-less/exploratory projects**
  with an honest escape hatch — proxy / checkable signal / explicit "exploratory"
  (open question #5). Do not build cold.

## Deferred — accepted, phase/track pending

- **[DEC-004](decisions/DEC-004-subagent-execution-mode.md) Phase 3** — mechanical
  per-agent `git worktree` isolation. Rule 2 ("one sub-agent, no interleaved tree
  ops") covers the hazard as convention; open Q1 (worth the bash-3.2 complexity?)
  unresolved.
- **[DEC-001](decisions/DEC-001-interface-contract.md) Phase 4** — an **MCP server**
  over the `--json` surface (`status` / `dash` / `validate` / cost as typed tools).
  Unblocked by Phase 1; a small, on-brand project that dogfoods the interface contract.
  - **"Turn the template into an app" (raised 2026-07-12) resolves *into* this.** The
    real question is *which layer* you productize. An app that generates the **content**
    (specs / design prose from a brief) is an anti-pattern — it re-wraps the agent and
    hides the disciplined thinking that *is* the value ("coach, don't wrap"). Productize
    the **read / governance / orchestration surface** instead — which is exactly this MCP
    server. Build it *as a real `PROJ` that dogfoods the template* (not speculative
    feature-work); that project also generates the orchestration-cost data the co-design
    item below needs. One move, two payoffs.
- **[DEC-002](decisions/DEC-002-cost-convention.md)** — contribute the `cost.*`
  convention upstream to ContextCore (which has no cost/USD convention). Proposed;
  ready prompt in the DEC appendix.

## Open harvest backlog — buildable now (not urgent)

- ~~**#8** — `roadmap` surface *planned-but-unframed* stages (parse the brief's
  `## Stage Plan` checkboxes).~~ **✅ Shipped v0.6.14** — `just roadmap` renders a
  `planned` bucket (human + `--json`) from the brief's Stage Plan, de-duped
  against framed `STAGE-*.md` files. Scoped to `roadmap` only (not `backlog`):
  backlog's "stage backlog" is un-promoted *specs* inside a framed stage, a
  different layer from un-framed *stages*.
- **#9** — a per-language "known gotchas" appendix the build prompt links (complements
  the toolchain brief). Optional.
- **#10** — a scheduled-advisory CI convention (cron gate for vuln-DB drift). Optional.

> With #8 shipped, **no non-speculative "now-tier" solo build remains** — #9/#10
> are optional and everything else is co-design-with-a-real-project. The pause is
> now clean: next leverage is *using* the template on a real project.

## Co-design with the next project(s)

These are shaped by real usage — start them *on* a live project, not in the abstract:

- **DEC-009's derivation aid** (above) — the frame-time metric prompt + escape hatch.
- **#4 — contract-tests-as-guards kit** — a starter kit + named constraints
  (contrast-aa, state-not-color-only, compositor-only-keyframes) that turn subjective
  quality (motion/perf/a11y) into CI guards. A creative/visual project is its natural
  first user.
- **#11 — client-handover artifact + user-vs-contributor docs split → DEC-011.**
  A deliverable handover to the person you built it for (distinct from the internal
  agent↔agent `HANDOFF-*`). Needs a real external delivery to shape it.
- **Orchestration + framing cost attribution (raised 2026-07-12).** The cost model
  meters only where there's a boundary — the **sub-agent** (`build`/`verify` tokens come
  back in the Agent result; see the comment block in `scripts/cost-audit.sh`). Everything
  in the **main loop** — `frame`/`design`/`ship` plus all cross-spec orchestration — is
  nullable today, and *pre-spec* framing (deciding the stage breakdown before any spec
  exists) has no home at all (no `stage.cost`). Net effect: recorded cost is
  systematically **under-counted**, which quietly corrupts DEC-009's predicted-vs-realized
  loop. Two attribution boundaries:
  - **(a) session boundary** — a dedicated framing/orchestration session, one meter read
    at the end → a coarse `overhead` cost line. Portable; degrades to `null` where there's
    no meter (DEC-005). Manual but honest.
  - **(b) sub-task boundary** — push the work into sub-agents (the *same* trick
    `build`/`verify` already use) and define **orchestration = session total −
    Σ(metered sub-agents)** — the top-level residual you can never sub-task to zero.
    More elegant, but Claude-Code-specific; gate it like `metering_source`.

  Lean: coarse `overhead` bucket first, per-sub-task residual later. **Don't build cold —
  this is N=1.** It co-designs naturally *on the MCP-server project above* (orchestrating
  sub-agents to build it produces exactly this framing+orchestration spend). Touches
  [DEC-002](decisions/DEC-002-cost-convention.md) (cost convention),
  [DEC-004](decisions/DEC-004-subagent-execution-mode.md) (delegated-exec cost
  attribution), [DEC-009](decisions/DEC-009-business-value-metrics.md)
  (predicted-vs-realized). Future home: its own DEC once it recurs.

## Candidate conventions — unearned, watching

- **Productization axiom (from the "turn it into an app" discussion, 2026-07-12).**
  When productizing *any* layer, ask *which layer*: **the discipline is the value, not
  the artifact.** Tooling that exposes the **contract** (read / governance / orchestration,
  `--json`, MCP) amplifies adoption; tooling that generates the **content / judgment**
  dissolves the discipline it's meant to enforce. A rule of thumb for every future
  "should we automate this?" call. See DEC-001 Phase 4 above.
- **Repo-level vision + idea parking lot.** The template captures direction well
  *once* an idea is a `PROJ-NNN` brief, but has no home for pre-commitment vision or
  a candidate-idea backlog. A workspace-level `ideas.md` is the **live experiment**;
  fold a convention into the scaffold only if it earns N≥2 across projects.
- **#14 — scale-tier growth** (informational, from bragfile's scale-recs): AGENTS.md
  cold-read cost at ~40KB, an auto `decisions/INDEX.md` past ~25 DECs,
  constraint-linting vs honor-system, cross-project `depends_on:`. A "what breaks
  past this scale" list, not current defects.

---

*Shipped work is in [`CHANGELOG.md`](../CHANGELOG.md); the decision record is in
[`docs/decisions/`](decisions/); projects built with the template are catalogued in
[`PROJECTS.md`](../PROJECTS.md).*
