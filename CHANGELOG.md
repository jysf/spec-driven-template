# Changelog

All notable changes to this template. One entry per fix; newest at top.

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
