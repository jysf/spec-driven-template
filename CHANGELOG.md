# Changelog

All notable changes to this template. One entry per fix; newest at top.

## 2026-04-21 — Reports, cost tracking, business value (v5.2)

Three bundled features that are tightly coupled: reports need value
structure to tell a project's story; reports need cost data to cover
AI spend; value and cost both live in spec/stage/project front-matter,
so touching those files once for both is cheaper than separate sessions.

Nothing breaks for existing projects — old specs without `cost:` or
`value_link:` advance through cycles and archive as before. Reports
degrade gracefully on pre-v5.2 data. See
`MIGRATION_TO_REPORTS_AND_COSTS.md` for details and optional
backfill blocks.

### Added

- **Business value structure** at project and stage level.
  - `value:` block in project-brief front-matter: `thesis`,
    `beneficiaries`, `success_signals`, `risks_to_thesis`. Testable
    claim, not marketing.
  - `value_contribution:` block in stage front-matter: `advances`,
    `delivers`, `explicitly_does_not`. What this stage advances and
    what it's explicitly not trying to do.
  - `value_link:` scalar on specs. Optional one-sentence reference
    back to the parent stage's value. `null` is acceptable.
  - Applied to both variants' `_templates/` directories in lockstep.
  - `variants/*/projects/_templates/project-brief.md`,
    `variants/*/projects/_templates/stage.md`,
    `variants/*/projects/_templates/spec.md`.

- **Self-reported AI cost** on every spec.
  - `cost.sessions[]` accumulates one entry per cycle (design, build,
    verify, ship). Each entry: `cycle`, `agent`, `interface`,
    `tokens_input`, `tokens_output`, `estimated_usd`,
    `duration_minutes`, `recorded_at`, `notes`.
  - `cost.totals` (`tokens_total`, `estimated_usd`, `session_count`)
    computed at ship.
  - `interface` is a free string. Known values: `claude-code`,
    `claude-ai`, `api`, `ollama`, `other`. Open for future agents.
  - Null numeric fields are fine — reports skip nulls in sums, count
    them in `session_count`.

- **Daily and weekly reports.** Two new commands:
  - `just report-daily` → `reports/daily/YYYY-MM-DD.md`. Sections:
    snapshot (specs by cycle with IDs, project progress), value
    (project thesis, stage advances, value_link population), activity
    today (files touched), cost activity (sessions, WIP cost, specs
    missing cost data), flags (stalled specs, stale decisions), 24h
    git activity.
  - `just report-weekly [YYYY-MM-DD]` →
    `reports/weekly/YYYY-WNN.md`. ISO week; optional date arg for
    back-dated weeks. Sections: summary, value advancement,
    shipped-this-week table, cost breakdown by cycle/interface/top-3,
    decision activity, reflection notes from shipped specs, flags.
  - Both: idempotent (re-run overwrites), graceful on pre-v5.2
    content, deterministic, no daemons.
  - Scripts: `scripts/report_daily.sh`, `scripts/report_weekly.sh`.

- **`scripts/_lib.sh` helpers** for value/cost parsing and portable
  dates. Pure bash + awk + `date`; no `yq` dependency.
  `find_all_specs`, `get_spec_cycle`, `sum_cost_tokens_for_spec`,
  `sum_cost_usd_for_spec`, `sessions_recorded_on`,
  `count_cost_sessions`, `extract_value_link`, `get_project_thesis`,
  `get_stage_value_contribution`, `days_ago`, `iso_week_number`,
  `iso_week_bounds`, `spec_mtime_date`.
  Cost parsers disambiguate `estimated_usd` in sessions vs totals
  by 6-space vs 4-space indent.

- **`reports/`** directory with `daily/` and `weekly/` subdirs;
  sample outputs from the example project committed so users see
  what reports look like before running them.

- **`feedback/`** as a known home for downstream user feedback.
  Rename of the bragfile NOTES file into the dated-slug convention;
  new `_template.md` with front-matter (source, captured_at,
  captured_by, status); `archive/` subdir for addressed/deferred
  items.

- **Prompt updates** across 6 prompts in both variants.
  - 1b Project Brief, 1c Stage Frame, 2b Spec Design: populate the
    new value/cost fields during design.
  - 1d Stage Ship, 1e Project Ship: cross-check shipped
    `value_link`/`value_contribution` against the parent thesis.
  - Prompt 3 Build, 4 Verify, 5 Ship: append cost sessions; compute
    totals at ship; Verify flags specs missing cost data without
    blocking.
  - Prompt 6 Weekly Review: report `value_link` population rate and
    aggregate costs.

- **AGENTS.md sections.** Both variants gained `## 3. Business Value`
  and `## 4. Cost Tracking Discipline` between the Work Hierarchy
  and Tech Stack sections. Cycle-Specific Rules updated to include
  cost-session appends. Downstream sections renumbered;
  cross-references to section 14 updated. `feedback/` and
  `reports/` added to the Directory Structure diagram and Pointers
  list.

- **`MIGRATION_TO_REPORTS_AND_COSTS.md`** at repo root — short,
  leads with "nothing breaks," includes optional backfill blocks.

- **27 new test assertions** in `scripts/test.sh` (30 → 57 total).
  Covers: v5.2 shape in scaffolded specs/stages, AGENTS.md new
  sections, `just report-daily` + `report-weekly` file writing and
  content, idempotency (re-run overwrites), and graceful handling
  of pre-v5.2 data (the critical backwards-compat guarantee).

### Changed

- **`justfile`** gains `report-daily` and `report-weekly` commands.
- **Both variants' README.md** gain a Reports section and the two
  new commands in their common-commands block. Claude-only's
  section-13 cross-reference updated to section 15 to track the
  AGENTS.md renumbering.

## 2026-04-20 — Hardening pass

First polish of the scripts after v5 delivery. Focus was bug-fix only,
exercised on macOS (the original build was tested on Ubuntu). No new
features, no variant dedup, no prompt changes.

### Fixed (follow-on, same-day — reported by downstream user building bragfile)

- **`archive-spec` stage-shipped message no longer falsely claims
  completion.** Archiving the last active spec under a stage used to
  print "All specs for STAGE-X are shipped", which was a false
  positive whenever the stage's Spec Backlog still listed unwritten
  specs. Reworded to "No active specs remain for STAGE-X" — an
  observation, not a completion claim. Stage completion judgment
  stays with the user (and the Stage Ship prompt).
  (`scripts/archive-spec.sh`)

- **Scaffolded specs and stages now pick up the real repo ID.**
  Every template hardcoded `id: my-app` in its `repo:` block;
  `.repo-context.yaml` had a "REPLACE" comment but nothing read
  that file. Even after the user updated `.repo-context.yaml`,
  every new spec/stage still stamped `my-app`. Same fix pattern as
  `__TODAY__`: templates use `__REPO_ID__`, `new-spec`/`new-stage`
  substitute the value parsed from `.repo-context.yaml`
  (`metadata.repo.id`), with `my-app` as the fallback so behavior
  never regresses on a pristine clone.
  (`scripts/_lib.sh`, `scripts/new-spec.sh`, `scripts/new-stage.sh`,
   `variants/*/projects/_templates/*.md`,
   `variants/*/decisions/_template.md`)

### Fixed

- **`just init` no longer silently half-initializes on re-run.** The
  recipe chained steps with `\ ;`, so a failed `cp` would still print
  `✓ Done`, write `.variant`, and leave a broken repo. Now chained with
  `&&` and guarded by a second check that aborts if `variants/` is
  missing. The "already initialized" hint now tells the truth: init is
  one-shot, restore from git or re-clone to start over.
  (`justfile`)

- **`advance-cycle` preserves the cycle-legend inline comment.**
  `update_frontmatter_scalar` used to wipe everything after `:`,
  stripping `# frame | design | build | verify | ship` on first use.
  The updater now preserves any trailing `# …` comment.
  (`scripts/_lib.sh`)

- **`archive-spec` refuses to re-archive a shipped spec.** Running
  `archive-spec SPEC-NNN` twice used to produce `specs/done/done/…`
  because `find_spec` happily returned already-archived files. Now
  `find_spec` excludes `*/done/*`, so both `archive-spec` and
  `advance-cycle` fail loudly with `Spec not found` on archived specs.
  (`scripts/_lib.sh`)

- **`weekly-review` emits repo-relative paths consistently.** Files
  discovered via `find` printed with absolute paths while hand-listed
  files were relative. The prompt promises "paths relative to repo
  root"; this change makes the output match.
  (`scripts/weekly-review.sh`)

- **`YYYY-MM-DD` → today's-date substitution no longer touches comment
  lines.** Templates used the same token for real placeholder values
  and format-documentation comments like `# optional: YYYY-MM-DD`.
  After substitution the comment read like a real target date. Real
  placeholders are now `__TODAY__`; format comments stay as
  `YYYY-MM-DD`.
  (`variants/*/projects/_templates/spec.md`,
   `variants/*/projects/_templates/stage.md`,
   `scripts/new-spec.sh`, `scripts/new-stage.sh`)

- **Removed dangling `just new-project` references.** The die() message
  in `_lib.sh` and the example `brief.md` in both variants pointed
  users at a command that doesn't exist. Replaced with accurate
  instructions (copy `projects/_templates/project-brief.md` into
  `projects/PROJ-NNN-<slug>/brief.md`).
  (`scripts/_lib.sh`, `variants/*/projects/PROJ-001-example-mvp/brief.md`)

### Added

- **`just test` / `scripts/test.sh`** — end-to-end happy-path test that
  spins up a temp copy, runs init + full cycle + archive + weekly-review,
  and asserts the invariants the fixes above depend on. No new deps.
  Intended for template maintainers.
