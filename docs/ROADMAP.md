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

- ~~**Expected-vs-actual estimation loop (raised 2026-07-18).**~~ **✅ Shipped v0.6.26** — the cheap half is built (t-shirt `XS|S|M|L|XL|XXL` expected size + `task.complexity_actual` at ship + optional `cost.tokens_estimate` + `just calibration`, warn-only). The size→token band is **derived from this repo's own shipped specs** rather than a shipped lookup table, so it earns trust as n grows. Still open, and deliberately not built cold: whether the drift view belongs in the project-close rollup, and whether stage-level estimates are worth capturing at all. Original capture:

- **Expected-vs-actual estimation loop (raised 2026-07-18).** Capture the
  prediction alongside the outcome so the template can tell you *how good your
  estimates are* — the feedback loop, not the number, is the value. Two axes:
  - **Size** — expand `task.complexity` (`S | M | L`) to a t-shirt scale
    `XS | S | M | L | XL | XXL`, recorded as the **expected** size at design/frame,
    plus an **actual** size stamped at ship. ("L means split it" shifts: `XL`/`XXL`
    almost certainly means it's a stage, not a spec.)
  - **Tokens** — an optional token **estimate** at design vs the **actual**
    (`cost.totals.tokens_total`, already captured). Ideal refinement: map each
    t-shirt size to a coarse token **band** (calibrated per-repo over time) so the
    size *is* a rough token estimate — answering "can we even estimate tokens?"
    with "yes, via the size you already assign."
  - **The loop** — a `just calibration` view (or a `specs-by-stage` column) showing
    expected-vs-actual drift per spec/stage: are we systematically under- or
    over-estimating? Feeds [DEC-009](decisions/DEC-009-business-value-metrics.md)
    (predicted-vs-realized), the orchestration **cost-gap** thread, and the
    project-close rollup (close is where the whole wave's drift is knowable).
  - **Discipline:** warn-only, never a gate. **Start cheap** — expected size +
    actual size + actual tokens are all near-free (the fields mostly exist); add
    the size→token-band mapping only once there's real data to calibrate against.
    Don't build the calibration view cold.

- **Closing / ending a project (raised 2026-07-18).** The template is strong on
  *starting* a wave (frame → brief → stage plan) and near-silent on *ending* one.
  Today closing is manual and easy to half-do: flip `status`, maybe stamp
  `shipped_at`, maybe fill the Project-Level Reflection. Nothing checks it, and
  nothing distinguishes the ways a project can end. Ideas to shape:
  - **Name the end states honestly.** `shipped` (delivered the thesis) is not the
    only ending. A project can be **abandoned** (stopped, thesis unproven),
    **superseded** (its thesis moved into another project), or **parked**
    (`on_hold`, may resume). Today `cancelled` flattens all three, which destroys
    the most interesting signal — *why* work stops. Cheap fix: keep the coarse
    enum, add an optional `closed_reason:` (open set, warn-only — the
    `activity` precedent).
  - **A guided `just close-project`** — the ritual, not just a status flip:
    refuse (or loudly warn) while specs are still in flight; stamp `shipped_at`;
    prompt the Project-Level Reflection; force the open **signals** to a
    disposition (the v0.5.18 close ritual already says dispositions happen at
    project close — nothing enforces it); print the final cost + value rollup.
  - **Predicted-vs-realized at close** — the natural home for
    [DEC-009](decisions/DEC-009-business-value-metrics.md)'s loop: compare the
    brief's `value.thesis` / `success_signals` against what actually shipped, and
    record time-to-value (`created_at` → `shipped_at`). Closing is the *only*
    moment the whole wave is knowable.
  - **A "ready to close" calm state** — a project whose specs are all shipped is
    *informational*, not a nag. (standup currently raises a `NEEDS_CLOSE` warning;
    its own lifecycle proposal wants this downgraded. Producer-side support here
    would settle it for every consumer.)
  - **Where the artifacts go** — closing is the natural trigger for the
    client/delivery handover (#11) and ties to the open "where do spec-driven
    artifacts live / repo declutter" question. A closed project probably wants to
    stop cluttering active views without being deleted.
  - **Don't over-build:** the honest minimum is *(a)* `closed_reason:` and *(b)* a
    close checklist in `AGENTS.md`. The `just close-project` command should earn
    itself on a real close, not be built cold.

- **[DEC-011](decisions/DEC-011-roadmap-structure.md) — roadmap structure
  (drafted 2026-07-13, proposed).** Unifies the two roadmaps that already exist and
  disagree: the template's **derived** roadmap (`just roadmap` = framed + planned
  stages) and standup's **declared** `roadmap:` brief block (pillars +
  `resume_when`). One project-level structure fed by *derive + declare*, a small
  `kind` set (`framed|planned|pillar|goal`), buckets-first horizon
  (`now|next|later` + optional `resume_when`/`target`), emitted via `just roadmap
  --json` so **standup consumes one typed surface** instead of re-parsing briefs.
  Optional + degradable (not every tracked repo is spec-driven). Sits **below** the
  Goals/Plans layer and **beside** DEC-009 (a roadmap `goal` is where a
  `value_metric` attaches). Phase 1 (bless schema + `just roadmap` merges
  declared+derived + `--json`) is the smallest increment and ships value to standup
  immediately. Don't build cold — validate on the harvest + by wiring standup.

- **Higher-level Goals + Plans layer (raised 2026-07-12).** A layer *above* the
  current `Repo → Project → Stage → Spec → Cycle` hierarchy, for capturing intent
  at portfolio scale (and the parent of [DEC-011](decisions/DEC-011-roadmap-structure.md)'s
  per-project roadmap — a Plan's roadmap is the union of its projects'):
  - **Plan** — groups **multiple Projects** into one initiative/program (a Project
    is a single wave; a Plan is the arc across several).
  - **Goal** — an outcome that can connect to a Plan and/or a Project, **and can
    also stand alone** as lightweight data capture (not every goal needs a home in
    the tree; some are just recorded, no deep modeling required).

  **Deliberately not designing the data model yet** — capture the intent first, let
  real use shape it. Strong tie to
  [DEC-009](decisions/DEC-009-business-value-metrics.md): a Goal is the natural
  parent of DEC-009's outcome-target / `value_metric` (value/outcome lives on a
  Goal), so the two should co-design. Open (later, not now): is a Plan a new
  artifact dir or just metadata linking existing `PROJ-*`? Do Goals live in a
  ledger (like `guidance/signals.yaml`) or as front-matter with links? How do
  goal↔plan↔project connections express — fields vs a link graph? Earn the design
  via a real Plan spanning ≥2 projects.

- **[DEC-009](decisions/DEC-009-business-value-metrics.md) — measurable value +
  time-to-value.** *(Flagged important 2026-07-12.)* Spine (outcome targets on the
  stage) is likely right, but the **metric-derivation aid** must be validated at a
  real project's *frame* (deriving the target metric live), **and it must handle
  goal-less/exploratory projects** with an honest escape hatch — proxy / checkable
  signal / explicit "exploratory" (open question #5). Do not build cold — the
  3-disciplined-project harvest is its validation path, and the Goals layer above
  is its likely parent.

## Deferred — accepted, phase/track pending

- **[DEC-004](decisions/DEC-004-subagent-execution-mode.md) Phase 3** — mechanical
  per-agent `git worktree` isolation. Rule 2 ("one sub-agent, no interleaved tree
  ops") covers the hazard as convention; open Q1 (worth the bash-3.2 complexity?)
  unresolved. **Direction confirmed 2026-07-12: the guidance is right.** Added axis
  — if built, the isolation helper need not be bash; consider a compiled
  single-binary runtime (**Zig** or similar) that owns the worktree lifecycle more
  safely, weighed against the zero-dep portability promise (see DEC-004 open Q1).
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
  the toolchain brief). Optional. *(2026-08-10: reframed as one half of the
  **golden paths + gotchas** candidate below — the gap is not the appendix, it is
  that the template has no instance-to-instance transfer mechanism at all.)*
- **#10** — a scheduled-advisory CI convention (cron gate for vuln-DB drift). Optional.
- **DEC-index at scale** — an auto-generated `decisions/INDEX.md` (id · title · status ·
  supersedes) once a project passes ~25 DECs, so the decision log stays navigable and
  cheap to cold-read. **Promoted from #14's "watching" list 2026-07-17 — now evidenced:**
  a dogfood survey found crustyimg carries **73** DECs and bragfile **39**, both well
  past the threshold. Ties to the `context-coldread-cost` signal; buildable now against
  the DEC front-matter (the DEC-001 schema already gives id/status/supersedes).

> #8 shipped, and the **DEC-index fix has since earned its way in** (crustyimg's 73 DECs
> is the wall #14 predicted) — that's the one non-speculative "now-tier" solo build now on
> the board. #9/#10 stay optional; everything else is co-design-with-a-real-project. Next
> leverage is still *using* the template on real projects.

## Co-design with the next project(s)

These are shaped by real usage — start them *on* a live project, not in the abstract:

- **DEC-009's derivation aid** (above) — the frame-time metric prompt + escape hatch.
- **#4 — contract-tests-as-guards kit** — a starter kit + named constraints
  (contrast-aa, state-not-color-only, compositor-only-keyframes) that turn subjective
  quality (motion/perf/a11y) into CI guards. A creative/visual project is its natural
  first user.
- **#11 — client-handover artifact + user-vs-contributor docs split → a future DEC**
  (the DEC-011 number went to roadmap structure; client-handover is unwritten and
  will take the next free number when it earns one).
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
  sub-agents to build it produces exactly this framing+orchestration spend).

  > **Update 2026-08-10 — the handback materially unblocked (b).** Approach (b) was
  > stuck because the residual is only computable when every delegated cycle is
  > metered, and non-Claude agents weren't. The **`handback:` block** (v0.6.28) now
  > yields Σ(delegated cost) for *any* agent, so **orchestration = session total −
  > Σ(handbacks)** is computable outside Claude Code for the first time. Two gaps
  > remain, and the second is the interesting one:
  > 1. Reading the orchestrator's own session total (manual `/cost` — fine).
  > 2. **Pre-spec framing still has nowhere to live.** Deciding a stage's breakdown
  >    happens before any spec exists, so there is no artifact to attach cost to.
  >    `stage.cost` does not exist — that's a schema gap, and the cheapest honest
  >    first cut. **Resist per-spec attribution of orchestration**: it is a split you
  >    cannot observe, so any number is false precision. Stage grain or nothing.
  >
  > Still don't build it cold. **grebe makes it N=2** — instrument grebe to *collect*
  > orchestrator session totals by hand into the stage file, then let real numbers
  > shape the tooling.

  Touches
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
- **Where do the spec-driven artifacts live? — repo-declutter / artifact storage
  (raised 2026-07-17).** Across many waves, shipped **specs already self-clean** to git
  history (a dogfood survey found bragfile at 6 waves keeps 1 spec file on disk, zany 0),
  but the **DEC log and cold-read corpus grow monotonically** (crustyimg 73 DECs). The
  open, unanswered question: must governance/spec artifacts always live *in* the app repo?
  This collides head-on with the deliberate **"the repo is the app"** axiom
  ([blog](blog/2026-06-02-the-repo-is-the-app.md)) + literal-artifact-as-spec. Two honest
  resolutions, kept strictly separate:
  - **(a) within the axiom — better in-repo cleanup.** Archive completed waves, the
    `decisions/INDEX.md` fix above, sub-template extraction to relieve cold-read cost
    (ties `context-coldread-cost`). This is the template's lane; earn each piece from a
    real project hitting the wall (crustyimg's 73 DECs is one such wall).
  - **(b) departing from the axiom — an external artifact store** that projects into the
    repo on demand. This does **NOT** belong in the template (it breaks the axiom the
    template is built on); it is the natural **second pillar of the helper-app**
    (`~/PSeven/ideas.md` #6 — "own the artifacts so they don't clutter the app repo").
    Do not fold (b) into the template.
- **#14 — scale-tier growth** (informational, from bragfile's scale-recs): AGENTS.md
  cold-read cost at ~40KB, constraint-linting vs honor-system, cross-project
  `depends_on:`. A "what breaks past this scale" list, not current defects. *(The
  `decisions/INDEX.md`-past-~25-DECs item graduated to the buildable backlog above,
  2026-07-17 — crustyimg's 73 DECs made it real.)*

- **Build bake-off — N-version build, and what it really buys (raised 2026-08-10).**
  Run the *same* spec through two or more build agents, verify each independently,
  then pick. The template accidentally already emits the artifact a fair bake-off
  needs: a self-contained work order with testable acceptance criteria and
  prescribed failing tests. Two design constraints, both learned from the existing
  lanes:
  - **Verify must not select.** The moment a verify session picks a winner it is
    invested in that winner and stops being a cold reviewer for it. Verify each
    build independently against the spec; make selection a *separate* step.
  - **Record the losers.** Two builds = two branches, two `## Build Completion`
    blocks, two cost entries, one discard. Throwing the loser away discards the
    actual prize.

  **The prize is not the better build — it's learning which agent is better at
  what.** `spec.agent.tier_map` is currently set once, by judgement, with zero
  evidence behind it; a handful of bake-offs turns it into a *measured* setting
  that compounds across every later spec. It is N× build cost, so it is a **stakes
  tier, not a default** (same shape as the patch lane, pointed the other way).
  Open: where a bake-off is recorded (N `claimed_by` holders on one spec breaks
  the single-holder lease); whether the loser's cost counts toward the spec.
  **Do not build tooling first** — run it by hand on 3–5 high-stakes specs and
  record which agent won and why. grebe (two external agents already configured)
  is the natural first bed.

- **Golden paths + per-language gotchas — the sideways gap (raised 2026-08-10).**
  Two faces of one thing: **gotchas are the anti-pattern list, golden paths the
  pattern list**, and both are per-stack knowledge. What makes this more than
  roadmap #9: `guidance/toolchain-brief.md` is **per-repo and instance-local**,
  but this knowledge wants to be **cross-repo** — the whole point is carrying what
  bragfile learned into grebe. **The template has no instance-to-instance transfer
  mechanism at all.** Everything flows *up* through harvests into the template and
  *down* into new scaffolds; there is no sideways. That absence is the real
  finding.
  - Capture seam that already fits: `guidance/signals.yaml` types are all
    *problems* (`lesson` / `process-debt` / `product` / `risk`). There is **no type
    for "this worked so well another project should copy it wholesale."** A
    `golden-path` type raised at project close would inherit the disposition
    ritual unchanged.
  - **The bar applies harder here, not softer.** A wrong paved road is worse than
    no road, because people follow it. Capture candidates aggressively; promote
    almost nothing. N=3 or it stays a preference.
  - Open: does a golden path live in the template (shipped to every scaffold), in
    a cross-instance store, or only as a harvest note? Ties to the artifact-storage
    question above and to the `instances.md` registry.

- **Instance registration has no trigger (raised 2026-08-10) — parked, owner
  sees no value now.** Nothing registers a new instance in
  [`instances.md`](harvests/instances.md): no script or recipe touches it, and
  every row currently there was added retroactively in one bulk pass. The
  structural reason it will keep happening is that **registration belongs in the
  template repo, but the event that should trigger it — scaffolding a project —
  happens in a different repo**, where nothing prompts you. Cheap fix if it ever
  earns its way in: `just init` / `just fresh-start` already knows the repo name,
  variant and template version at exactly the right moment, so it could print a
  paste-ready registry row (it can't edit the template repo, but it can hand you
  the line).

  **Deliberately not built.** Asked 2026-08-10; the owner's answer was "I don't
  see the value right now." Record that as evidence, not as a deferral — the
  Discipline column in `instances.md` was *removed* on exactly this signal
  (nobody could fill it, so it was noise). A registry maintained in bulk every
  few months may simply be good enough for a handful of instances; the prompt
  only earns itself if a harvest is ever actually blocked by a missing row. When several coding
  agents work one repo, isolate with **`git worktree`, not clones**. The rule:
  **the code can be isolated; the record must not be.** A clone forks the memory —
  a spec's cost lands in one copy and its `DEC-*` in another, `signals.yaml`
  diverges — which destroys the one thing the template exists to protect. Recorded
  here so the question doesn't get re-asked; it strengthens the case for
  [DEC-004](decisions/DEC-004-subagent-execution-mode.md) Phase 3 rather than
  competing with it. If the real need is *different instructions per agent*, that
  is a `guidance/agents/<name>.md` the handoff links (sibling of the toolchain
  brief), not a repo fork.

---

*Shipped work is in [`CHANGELOG.md`](../CHANGELOG.md); the decision record is in
[`docs/decisions/`](decisions/); projects built with the template are catalogued in
[`PROJECTS.md`](../PROJECTS.md).*
