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

Legend: ✅ required · ◦ optional · `enum{…}` allowed values.

---

## `.repo-context.yaml` — the repo (a ContextCore `RepoContext`)

```
apiVersion: contextcore.io/v2 ✅      kind: RepoContext ✅
metadata.repo: { id ✅, name ◦, purpose ◦, url ◦ }
metadata.business: { criticality ◦ enum{critical,high,medium,low}, owner ◦, contacts[] ◦ }
spec.stack: { language, runtime, framework, database, hosting }  ◦
```

## `projects/PROJ-*/brief.md` — a project

```
project: { id ✅, status ✅ enum{proposed,active,shipped,cancelled}, priority ✅ enum{critical,high,medium,low}, target_ship ◦ }
repo.id ✅
created_at ✅   shipped_at ◦
value: { thesis ◦, beneficiaries[] ◦, success_signals[] ◦, risks_to_thesis[] ◦ }
```

## `projects/PROJ-*/stages/STAGE-*.md` — a stage (epic)

```
stage: { id ✅, status ✅ enum{proposed,active,shipped,cancelled,on_hold}, priority ✅ enum{critical,high,medium,low}, target_complete ◦ }
project.id ✅   repo.id ✅
created_at ✅   shipped_at ◦
value_contribution: { advances ◦, delivers[] ◦, explicitly_does_not[] ◦ }
```

## `projects/PROJ-*/specs/SPEC-*.md` — a spec (the unit `just validate` gates)

```
task: { id ✅, type ✅ enum{epic,story,task,bug,chore}, cycle ✅ enum{frame,design,build,verify,ship},
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

`guidance/questions.yaml` is the same model with `guidance.type = question`.

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
