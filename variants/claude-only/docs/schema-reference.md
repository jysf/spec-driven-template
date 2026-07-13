# Schema reference — the front-matter contract

The YAML front-matter on each artifact **is the public API** of this repo: it's
what the `just` commands, the reports, `--json` output, and any downstream
consumer (an MCP server, a ContextCore exporter, a UI) read. This document is
the canonical shape. Field names follow ContextCore / OTel semantic conventions
where they overlap (see the alignment section at the end).

> `DEC-NNN` references point to the **spec-driven template's own design log**
> (its `docs/decisions/`), not files in this repo.

**What enforces what:**
- `just validate` — every spec has the required **structural** fields below with
  valid values. Gate: exits non-zero on any violation (CI-suitable).
- `just cost-audit` — every *shipped* spec has real build/verify cost.
- `just decisions-audit` — `DEC-*` records are structurally sound + scope-linted.

Legend: ✅ required · ◦ optional · `enum{…}` allowed values · `set{…}` suggested/open values (validate warns-only on anything outside, never fails).

---

## `.repo-context.yaml` — the repo (a ContextCore `RepoContext`)

```
apiVersion: contextcore.io/v2 ✅      kind: RepoContext ✅
metadata.repo: { id ✅, name ◦, purpose ◦, url ◦ }
metadata.business: { criticality ◦ enum{critical,high,medium,low}, owner ◦, contacts[] ◦ }
spec.stack: { language, runtime, framework, database, hosting }  ◦
spec.agent: { default_model ◦, tier_map{design,build,verify} ◦ }              # DEC-005
spec.cost:  { metering_source ◦ enum{subagent_tokens,api_usage,manual,none}, rate_per_mtok ◦, currency ◦ }  # DEC-005
```

`spec.agent` / `spec.cost` (DEC-005) parameterize the model + cost seams so the
template runs on a non-Claude agent by config, not a fork. Defaults reproduce the
Claude-Code workflow. `just cost-audit` honors `spec.cost.metering_source`:
`none` disables the gate (no token source on the platform); anything else keeps
it enforced. See `docs/porting.md`.

## `projects/PROJ-*/brief.md` — a project

```
project: { id ✅, status ✅ enum{proposed,active,on_hold,shipped,cancelled}, activity ◦ set{requirements,design,build,test,blocked}, priority ✅ enum{critical,high,medium,low}, target_ship ◦ }
repo.id ✅
created_at ✅   shipped_at ◦
value: { thesis ◦, beneficiaries[] ◦, success_signals[] ◦, risks_to_thesis[] ◦ }
```

**`status` vs `activity` — two axes, don't conflate them.** `status` is the
**coarse, machine-keyed** lifecycle state that tooling branches on (keep it to the
enum above). `activity` is an **optional, human-facing** refinement of the work
happening *within* an `active` project — it says *what kind of work is going on
right now* without abusing `status` or making a project look stalled. Its
vocabulary is a **suggested open set** (`requirements | design | build | test |
blocked`), extend it as needed (e.g. `spike`); `validate` warns on an
unrecognized value but never fails. Example — a live project gathering
requirements before any spec is framed:

```
project:
  id: PROJ-006
  status: active
  activity: requirements
```

Downstream consumers may treat some activities as deliberately quiet phases
(e.g. suppress "cut a release" / "close this project" nudges during
`requirements`).

## `projects/PROJ-*/stages/STAGE-*.md` — a stage (epic)

```
stage: { id ✅, status ✅ enum{proposed,active,shipped,cancelled,on_hold}, priority ✅ enum{critical,high,medium,low}, target_complete ◦ }
project.id ✅   repo.id ✅
created_at ✅   shipped_at ◦
value_contribution: { advances ◦, delivers[] ◦, explicitly_does_not[] ◦ }
```

## `projects/PROJ-*/specs/SPEC-*.md` — a spec (the unit `just validate` gates)

```
task: { id ✅, type ✅ enum{epic,story,task,bug,chore,release}, cycle ✅ enum{frame,design,build,verify,ship},
        blocked ◦, priority ◦, complexity ✅ enum{S,M,L} }
project: { id ✅, stage ✅ }            repo.id ✅
agents: { architect ◦, implementer ◦, created_at ◦ }
references: { decisions[] ◦, constraints[] ◦, related_specs[] ◦ }
value_link ◦
cost: …                                 ◦ structurally; ✅ on shipped specs via cost-audit
```

The **required structural set** `just validate` enforces: `task.id`,
`task.type`, `task.cycle` (valid enum), `task.complexity` (valid enum),
`project.id`, `project.stage`, `repo.id`. Files under `specs/prompts/` and
`*-timeline.md` are not specs and are skipped.

A **release spec** (`task.type: release`, DEC-006) is a spec subtype: it reuses
this exact schema (so `validate` / `cost-audit` / `status` treat it as a normal
spec — `status` tags it `[release]` and exposes `task.type` in `--json`) and
adds a generic runtime **pre-flight checklist** in the body. Scaffold it with
`just new-release-spec "vX.Y.Z" STAGE-NNN` (or `just new-spec … --release`).

## `projects/PROJ-*/patches/PATCH-*.md` — a patch (the patch lane, DEC-003)

A **patch** is a bounded fix to already-shipped behavior; it uses the same
`task.*` schema as a spec so `just validate` / `cost-audit` / `status` treat it
as first-class, with two differences: `task.cycle` is the collapsed
`patch|verify|ship`, and there is **no `project.stage`** (a patch attaches to the
project, not a stage).

```
task: { id ✅ (PATCH-NNN), type ✅ =patch, cycle ✅ enum{patch,verify,ship},
        blocked ◦, priority ◦, complexity ✅ enum{S,M,L} }
project.id ✅   repo.id ✅            agents: { implementer ◦, verifier ◦, created_at ◦ }
references.decisions[] ◦
cost: …                                 ◦ structurally; ✅ on shipped patches (patch+verify) via cost-audit
```

`just validate` requires `task.id/type/complexity`, `task.cycle` ∈
{patch,verify,ship}, `project.id`, `repo.id` (not `project.stage`). `cost-audit`
requires a real `tokens_total` on the **patch** and **verify** cycles of a
shipped patch. See the patch-lane section in `AGENTS.md` and DEC-003.

### The `cost` block (template extension — see DEC-002)

```
cost:
  sessions:                              # one entry appended per cycle
    - cycle: <frame|design|build|verify|ship>
      agent: <model id>
      interface: <claude-code|claude-ai|api|ollama|other>
      tokens_total: <int>                # ONE combined count (real on build/verify)
      estimated_usd: <float>             # order-of-magnitude estimate
      duration_minutes: <number>
      recorded_at: <YYYY-MM-DD>
      notes: <string>
  totals: { tokens_total: <int>, estimated_usd: <float>, session_count: <int> }
```

`cost-audit` requires a positive `tokens_total` on the `build` and `verify`
cycles of shipped specs; `design`/`ship` (main-loop) may be null. No
ContextCore/OTel cost convention exists — this is a documented template
extension (DEC-002).

## `decisions/DEC-*.md` — a decision (ContextCore `insight.*`)

```
insight: { id ✅, type ✅ enum{decision,analysis,recommendation,observation}, confidence ✅ 0.0–1.0,
           audience[] ◦ enum{executive,developer,agent,operator} }
agent: { id ◦, session_id ◦ }
project.id ◦   repo.id ✅
created_at ✅   supersedes ◦   superseded_by ◦
affected_scope[] ◦                       # path globs; powers decisions-audit --changed
tags[] ◦
```

## `guidance/constraints.yaml` — repo rules (ContextCore `guidance.*`, type=constraint)

```
constraints[]: { id ✅, rule ✅, severity ✅ enum{blocking,warning,advisory},
                 paths[] ✅, added_by ✅, added_at ✅, rationale ✅ }
```

`severity` is about **enforcement**, not planning priority. Canonical mapping
from a critical/high/medium/low rating: `critical`/`high` → **blocking**,
`medium` → **warning**, `low` → **advisory** (also in the `constraints.yaml` header).

`guidance/questions.yaml` is the same model with `guidance.type = question`.

## `guidance/signals.yaml` — the typed feedback ledger (template extension)

```
signals[]: { id ✅, type ✅ enum{lesson,process-debt,product,risk}, summary ✅,
             evidence ✅, bar ◦ (lessons only), status ✅ enum{open,watch,accepted,
             rejected,codified,done,dropped}, disposition_at ✅ enum{stage-close,
             project-close}, first_flagged ✅, last_touched ✅, raised_by ✅, notes ◦ }
```

One ledger for every feedback type, so nothing rots un-decided (`lesson` is
dispositioned at a stage close and keeps the N=3/N=2 codification bar;
`process-debt`/`product`/`risk` at a project close). The forcing function is the
close-disposition ritual in `FIRST_SESSION_PROMPTS.md` (Prompts 1d/1e), not a CI
gate. Browse with `just dash signals`; the open count surfaces in `just dash`'s
flags. No ContextCore/OTel namespace spans all four types, so `--json` emits a
template-native `signal.*` payload (like `cost.*`, a documented extension). Full
authoring guide + migration note: `docs/signals.md`.

## `projects/PROJ-*/handoffs/HANDOFF-*.md` — *(claude-plus-agents only)* (ContextCore `handoff.*`)

```
handoff: { id ✅, from_agent ✅, to_agent ✅, from_role ◦, to_role ◦, created_at ✅,
           status ✅ enum{pending,accepted,completed,rejected} }
task.spec_id ✅   project: { id ✅, stage ✅ }   repo.id ✅
```

---

## ContextCore / OTel alignment

The field names above mirror ContextCore's semantic conventions (verified
against its `docs/reference/` + `semconv/registry/`); see
DEC-001 §5 for the full crosswalk.
In short: `task.*`, `project.*`, `business.*`, `insight.*`, `guidance.*`,
`agent.*`, `handoff.*` align; `task.cycle` is the template's SDLC specialization
of `task.status` (no 1:1); and `cost.*` is a template extension that ContextCore
and OTel GenAI don't yet have (DEC-002 proposes it upstream). `--json` output
(DEC-001 §2) carries these attribute names so the repo can feed a ContextCore /
OTel pipeline without scraping.

> Versioning: a `schema_version` per artifact is planned so changes are
> detectable; until then, schema changes are tracked via decisions + a migration
> note (precedent: `MIGRATION_TO_REPORTS_AND_COSTS.md`).

---

## Structured output (`--json`) and exit codes

The read/dashboard commands accept `--json` for machine-readable output — the
contract a consumer (an MCP server, a ContextCore exporter, a dashboard) reads
instead of scraping text. Supported: `dash` (and every lens — `now` / `next` /
`future` / `ledger`), `status`, `specs-by-stage`, `roadmap`, `backlog`. Default
human output is unchanged.

Stable envelope:

```
{ "schema_version": 1, "command": "<name>", "generated_at": "<UTC ISO-8601>",
  "data": { … } }
```

The `data` payload uses the ContextCore/OTel attribute names above (`task.id`,
`task.cycle`, `project.stage`, `cost.tokens_total`, `cost.estimated_usd`, …).
`just dash --json` stitches the `status` and `roadmap` reports plus a cost
rollup. The report generators (`report-daily` / `report-weekly`) emit markdown,
not `--json` — their files are already a portable artifact.

> If your `just` version intercepts the flag, pass it after `--`:
> `just status -- --json`.

Exit-code contract (DEC-001 §2):

| Code | Meaning |
|---|---|
| `0` | success (read commands always; gates when clean) |
| `1` | gate failure — a real violation (`cost-audit`, `validate`, `decisions-audit`) |
| `2` | usage error (unknown flag/argument) |
