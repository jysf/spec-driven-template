# Contributing

This is a template you can fork and adapt freely. If you want to send
changes back, here's what keeps the template coherent.

## Design principles (non-negotiable)

These are the constraints that make the template what it is. A change
that breaks one of them is almost always the wrong change:

- **Zero runtime dependencies.** Markdown, a `justfile`, and pure bash.
  No package to install to use it. Optional external tools are
  documented in `guidance/recommended-tools.md`, never required.
- **Bash 3.2 compatible.** macOS ships bash 3.2. No `mapfile`/`readarray`,
  no associative arrays (`declare -A`), no `\x01`-style escapes in `sed`.
  Build arrays with `while IFS= read -r`; do id→file lookups with
  parallel arrays + a linear scan.
- **Portable shell.** Scripts run on both BSD (macOS) and GNU (Linux)
  `sed`/`date`/`stat`. When they differ, branch on `uname` (see the
  date helpers in `scripts/_lib.sh`).
- **Escape user input.** Anything user-supplied that gets substituted
  into a file goes through `sed_escape_replacement` first. See
  `SECURITY.md`.
- **Both variants stay in parity.** `claude-only` and
  `claude-plus-agents` are kept in sync. A change to one variant's
  `AGENTS.md`, templates, or docs almost always needs the mirror edit
  in the other.

## Development loop

```bash
just template-selftest   # the end-to-end suite (init → full cycle → reports → audits)
```

`just template-selftest` scaffolds a throwaway repo in a temp dir and runs the
real commands against it. It must stay green. (The name is `template-selftest`,
not `test`, so a generated app keeps `just test` for its own suite.) When you add
or change a recipe:

1. Add coverage to `scripts/test.sh` (assert behavior, not just exit 0).
2. Update the command table in `README.md`.
3. Bump the top-level `VERSION` file (see Versioning below) and add a matching
   `CHANGELOG.md` entry — one per change, newest at the top, tagged with the
   same `vMAJOR.MINOR.PATCH`. A test drift-guards `VERSION` against the CHANGELOG.
4. If the change is user-facing, reflect it in the relevant `AGENTS.md`
   sections of **both** variants.

## Versioning

The template version lives in the top-level `VERSION` file (semver) and is
printed by `just template-version`. It is **pre-1.0** (`0.y.z`) — the command
surface and the front-matter/`--json` contract may still change. Bump it with
every change:

- While `0.y.z`: bump the minor `y` for a **breaking** change (renamed/removed
  recipe, changed output contract, incompatible schema). The DEC-001 Phase 3
  command consolidation is breaking, so it bumps the minor.
- Bump the patch `z` for an **additive** feature (new recipe/flag/`--json`
  field) or a fix.
- `1.0.0` marks the **first stable** release — declared once the command surface
  and the front-matter/`--json` contract are considered stable.

`VERSION` is top-level (not in `variants/`), so it survives `just init`: an
instance reports the template version it was scaffolded from.

## Style

- No trailing whitespace; every file ends with a newline.
- Comments explain *why*, not *what*. No dead code — delete it.
- Match the surrounding script's idioms (`_lib.sh` helpers, the
  `info`/`warn`/`die`/`success` output helpers, `set -euo pipefail`).
- Commits: conventional prefixes (`feat`/`fix`/`docs`/`refactor`/`test`)
  with a scope, e.g. `feat(decisions): …`.

## Where things live

- `scripts/` — the daily commands; `_lib.sh` is the shared library.
- `variants/claude-only/`, `variants/claude-plus-agents/` — the two
  scaffolds `just init` copies to the repo root.
- `justfile` — recipes; works both before init (`init`, `list-variants`)
  and after (everything else).
- `docs/`, `PROJECTS.md`, `SECURITY.md`, `CHANGELOG.md` — the template
  project's own docs (not copied into generated repos).
