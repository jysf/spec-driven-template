# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

**This is the template itself, not a project built with it.** That single fact
explains most of what looks odd here:

- There is **no `projects/` directory at the root**. The template does not run
  its own frame→design→build→verify→ship cycle on itself; it develops through
  the loop in `CONTRIBUTING.md`.
- **Its own decision records live in `docs/decisions/` (13 DECs), not
  `decisions/`.** A scaffolded instance keeps them at `decisions/`. Helpers
  resolve this via `decisions_dir()` in `_lib.sh` — root wins, `docs/decisions/`
  is the fallback. Anything new that reads DECs must use that helper, or it will
  silently see nothing here.
- **`just test` is not the test command.** That name is reserved for the app a
  user generates. The maintainer suite is `just template-selftest`.

`variants/claude-only/` and `variants/claude-plus-agents/` are the two scaffolds
`just init` copies to a repo root before deleting `variants/`.

## Commands

```bash
just template-selftest    # THE test suite — scaffolds a throwaway repo in a temp
                          # dir and runs init → full cycle → reports → audits.
                          # ~500 assertions. Must stay green.
just validate             # schema gate (specs/patches/spikes) — exits non-zero
just decisions-audit      # DEC structural lint + scope conflicts
just decisions-index      # regenerate docs/decisions/INDEX.md; --check for CI
just cost-audit           # shipped specs must carry real build/verify tokens
```

`scripts/test.sh` is a single 2,900-line bash script with no framework. There is
**no way to run one test** — it bails on first failure and prints the scratch
dir path so you can reproduce by hand:

```bash
cd /var/folders/.../tmp.XXXX/repo && just <the-failing-command>
```

To check a script against a real instance without installing anything, `cd` into
that repo and invoke this template's script by absolute path — they resolve
`REPO_ROOT` from the working directory:

```bash
cd ~/path/to/instance && /path/to/this/repo/scripts/roadmap.sh --json
```

## Architecture

- **`scripts/_lib.sh`** (~1,700 lines) is the shared library every script
  sources: front-matter readers (`get_spec_*`, `get_dec_*`, `get_stage_*`),
  JSON emitters, id resolution, portable date math. New readers belong here.
- **`justfile`** is thin dispatch — one recipe per script, no logic. `app.just`
  is the generated app's own recipes and is deliberately separate so a template
  update never clobbers them.
- **`--json` is a contract (DEC-001)**, not a convenience. Every read command
  emits `{schema_version, command, generated_at, data}`. Exit codes are load
  bearing: `0` ok, `1` gate failure, `2` usage error.
- **Front-matter is the public API.** Specs, stages, briefs, DECs and handoffs
  are markdown with YAML front-matter; `validate` gates its shape. Changing a
  field changes the contract for every downstream consumer.

`docs/ROADMAP.md` is the backlog and carries the reasoning behind unbuilt work.
`docs/decisions/` is why things are the way they are; start at its `INDEX.md`.

## Non-negotiable constraints

- **bash 3.2** (macOS default): no `mapfile`, no `declare -A`. Build arrays with
  `while IFS= read -r`; do id→file lookups with parallel arrays + linear scan.
- **Zero runtime dependencies.** No `yq`, no `jq` anywhere — YAML and JSON are
  parsed and emitted with awk and bash. (`test.sh` alone uses `python3` for JSON
  assertions, guarded by `HAVE_PY3` so it degrades when absent; nothing in the
  daily commands may.)
- **BSD *and* GNU** `sed`/`date`/`stat` — branch on `uname` (see `_lib.sh`).
- **Both variants stay in parity.** 31 of ~45 files are byte-identical across
  them. A change to shipped content is *two* edits, and forgetting the mirror is
  the most common mistake here.

## The contribution loop

Per `CONTRIBUTING.md`, a change is not done until all four are true:

1. Coverage added to `scripts/test.sh` — assert behavior, not exit 0.
2. `README.md` command table updated (new recipes).
3. `VERSION` bumped **and** a matching `CHANGELOG.md` entry added on top.
4. Both variants updated.

## Conventions with teeth

- **Ship the reader with the field.** A new field, flag or namespace lands in the
  same change as something that reads it. This is the repo's most recurring
  defect (N=5). Corollary: **assert on the reader in `test.sh`, never on the
  field's presence** — asserting a slot exists is exactly what let three of those
  five pass CI for months.
- **Verify claims against data before acting on them** (DEC-004 rule 1,
  generalized). Numbers in `ROADMAP.md` and in script header comments have
  repeatedly turned out to be unsupported by the corpus. Run the count.
  `CHANGELOG.md` is the reliable record of what exists; `ROADMAP.md` is
  deliberately full of proposals that were never built.
- **Warn by default; refuse rarely.** Open sets (`activity`, `closed_reason`,
  roadmap `kind`/`horizon`, `status`) advise and never gate. Refuse only when the
  missing thing *is* the failure the ritual exists to prevent — the precedent is
  `archive-spike` refusing without a `spike.outcome`, and `close-project`'s four
  refusals follow it. Note two of those four are **conditional on the ending
  claimed**: in-flight specs and an unscored thesis block a `shipped` close but
  not an `abandoned` one, which is what makes `closed_reason` load-bearing
  rather than a label.
- **Codification bar: N=3 same-outcome, or N=2 paired-opposing.** Don't promote a
  convention from one occurrence, and don't build roadmap items "cold" — most are
  marked as needing a real project first, and that gate is meant seriously.

## Gotchas that have cost real time

- **`update_frontmatter_scalar` only replaces.** On an artifact created before a
  field existed it silently no-ops. Use **`upsert_frontmatter_scalar`** for any
  newly-added field, or a command will report "recorded" while writing nothing.
- **The CHANGELOG drift guard requires the version in its own trailing
  parenthetical** — `## 2026-08-13 — title (v0.6.39)`. `(DEC-011 Phase 1,
  v0.6.39)` does not match and fails the suite.
- **`test.sh` runs under `set -euo pipefail`.** Piping a command that exits
  non-zero (any gate under test) sinks the whole pipeline regardless of what the
  consumer decides. Capture to a variable first, then inspect.
- **Never pipe into `head`.** It exits early, the producer gets SIGPIPE, and
  under `pipefail` the script dies with exit 141 and no message — only when the
  data is big enough, so it passes locally and fails later. Use `sed -n 1p`. The
  suite fails on any `| head` in `scripts/`.
