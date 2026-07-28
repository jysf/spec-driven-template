# Insight sources — template instances we learn from

The maintained registry of real repos built with (or tracked by) the template.
Each is a **feedback source**: friction and inventions found while shipping them
drive template changes. This list exists so gathering more insight is
*incremental* — scan for what changed since **Last reviewed**, rather than
re-deriving paths and re-reading everything.

**Discipline of this file:** update **Last reviewed** whenever an instance is read
for signals, and point **Insights captured in** at where the digested findings
already live (a harvest doc, `feedback/`, or a `docs/ROADMAP.md` thread) so we
never re-harvest what's already triaged. Repo names/URLs only — machine-local
paths are intentionally kept out (portability + hygiene; see the standup
`standup.toml` precedent).

> This is distinct from [`PROJECTS.md`](../../PROJECTS.md) (the public "built with
> this template" showcase) and from standup's operational tracked-repos list —
> though all three should stay roughly aligned.

## Registry

| Repo | Variant | Tier | Discipline | Insights captured in | Last reviewed |
|---|---|---|---|---|---|
| [`bragfile000`](https://github.com/jysf/bragfile000) | claude-only | full | ? confirm | `feedback/2026-04-20-bragfile-project.md`; [harvest 2026-07-06](2026-07-06-three-project-dogfood-harvest.md) | 2026-07-06 |
| `crustyimg` | claude-only | full | ? confirm | [harvest 2026-07-06](2026-07-06-three-project-dogfood-harvest.md) (framework-feedback) | 2026-07-06 |
| [`zany-animal-slots`](https://github.com/jysf/zany-animal-slots) | claude-only | full | ? confirm | `feedback/2026-07-0{3,4}-*`; [harvest 2026-07-06](2026-07-06-three-project-dogfood-harvest.md); lifetime-modes split → v0.6.17 | 2026-07-12 |
| `bragfile-report` | claude-only | full (aggregator) | ? confirm | [harvest 2026-07-06](2026-07-06-three-project-dogfood-harvest.md) | 2026-07-06 |
| `rspeed` | claude-only | full | ? confirm | [`PROJECTS.md`](../../PROJECTS.md) note only | **never harvested** |
| `uw` | **claude-plus-agents** | full | ? confirm | — | **never harvested** (only plus-agents instance — blind spot) |
| [`skillport`](https://github.com/jysf/skillport) | claude-only | full | ? confirm | v0.6.22 spec titles + the v0.6.19 Reflection-Q5 defect → v0.6.24 (see `CHANGELOG.md`) | 2026-07-18 |
| [`standup`](https://github.com/jysf/localStandupPlus000) | claude-only | full + **consumer/product** | explicit | standup design docs; deep-dive 2026-07-13 (memory); its own `docs/design/` | 2026-07-13 |
| `blog` | — | declared-lite (`.standup.yaml`) | n/a | — | — |

**Legend** — Tier: `full` = `.repo-context.yaml` spec-driven; `declared-lite` =
`.standup.yaml`; `non-template` = tracked but not scaffolded. Discipline: does it
follow the frame→design→build→verify→ship process explicitly, or loosely.

## To confirm (owner)

- **Which 3 follow the discipline explicitly?** (User noted ≥4 instances, 3
  explicit — mark the Discipline column.)
- **Canonical vs stale checkouts** — several repos have multiple worktrees/clones
  on disk; the registry tracks the *repo*, not each checkout.
- **Unharvested blind spots:** `uw` (claude-plus-agents) and `rspeed` have never
  been read for signals — worth a light pass if either is active.
- **`skillport`** is the newest and most active instance (two projects:
  `PROJ-001-skillport-lint`, `PROJ-002-skillport-audit`). It has already paid for
  itself twice — it surfaced the ID-only spec ledger (→ v0.6.22) and the missing
  Reflection-Q5 answer slot (→ v0.6.24) — but has never had a *deliberate* harvest
  pass; both findings arrived incidentally. It is the natural next harvest, and the
  live validation ground for `frame-stage` (do outlines survive?) and `calibration`
  (do the token bands stabilize?).
