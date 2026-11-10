# Harvest outcome 2026-11-10 — what the November batches shipped

The follow-through on
[`2026-11-03-irradiance-crustyimg-deep-analysis.md`](2026-11-03-irradiance-crustyimg-deep-analysis.md):
all seven batches in its "First batch (proposed)" list are built, plus CI for the
template itself. Ten releases, **v0.6.40 → v0.6.49**, 2026-11-04 to 2026-11-10.
`CHANGELOG.md` has the full entry for each; this page is the summary.

Most of the work fixed one failure shape: a tool that wrote wrong data, or
reported green or zero, while work sat in front of it.

## By batch

| # | Release | What it fixed |
|---|---|---|
| 1 | v0.6.40 | Data that was silently corrupted |
| 2 | v0.6.41 | Checks that could not fail |
| — | v0.6.42–44 | The template's own suite in CI |
| 3 | v0.6.45 | Ids handed out twice |
| 4 | v0.6.46 | Tools that reported zero with work in front of them |
| 5 | v0.6.47 | Scaffolding a new instance |
| 6 | v0.6.48 | Measuring cost |
| 7 | v0.6.49 | Getting fixes into existing instances |

### 1. Corrupted data (v0.6.40)

- One YAML-aware reader for front-matter scalars. The three old copies cut
  values at the first `#` and returned only the first line of a multi-line value.
- `handback-sync` writes `notes` as an escaped, quoted scalar. A raw note with a
  newline or `#` made the spec unparseable (irradiance SPEC-010, which then
  survived three later specs).
- `handback-sync` no longer appends a cycle twice. In claude-plus-agents the
  agents fill the handback only, and the orchestrator syncs it.

### 2. Gates that could not fail (v0.6.41)

- `validate` parses front matter: Ruby's `YAML.parse` when present, a bash check
  for the two known breakages otherwise, and it refuses green if the parser
  didn't run. Both variants' CI now run it.
- `decisions-audit --changed` falls back to `BASE...HEAD` on a clean tree.
  Before, verify (always a clean checkout) checked nothing.

### Template CI (v0.6.42–v0.6.44)

- `selftest.yml` runs `just template-selftest` on Ubuntu and macOS for every PR.
  The first runs found Linux-only bugs: unsorted `find` output, and Ruby 3
  rejecting dates.
- No script pipes into `head` any more (25 places), and the suite fails if one
  does. Under `pipefail` it could kill a script with exit 141 and no message
  once the data grew.

### 3. Ids (v0.6.45)

- `next_id` looks at other worktrees, local branches and remote-tracking refs,
  and skips `tests/` fixtures. irradiance minted duplicates at least 7 times.
- New `just id-audit` lists ids already used by two artifacts.

### 4. Silent zeros (v0.6.46)

- One backlog counter, keyed on structure rather than one marker string.
  crustyimg 96 → 129 open items, zany 0 → 3.
- `backlog` shows every active stage and every `proposed` project (81 items in
  crustyimg's were invisible).
- `find_stage` skips cycle prompts; `new-spec` no longer exits silently without a
  `stages/` dir; inline `affected_scope: [...]` is read.

### 5. Scaffold (v0.6.47)

- `just init` confirms, or takes the variant name as an argument.
- `init` removes the template's own material, about 4,800 lines: roadmap, blog,
  harvests, other instances' feedback, the example project and DEC.
- "No projects yet" is a state: `status`, `dash`, `info` and `cost-audit` exit 0,
  so a new instance's first CI run is green.
- `frame-stage` caps slugs at 60 characters and strips `(not yet written)`
  wherever it sits.

### 6. Cost (v0.6.48)

- The measuring method is in `docs/cost-tracking.md` and AGENTS §4: count each
  `message.id` once (summing lines over-counted 1.6–2.25×), include worktree and
  subagent transcripts, price each token component separately (one flat rate
  overstated 2.6–14.7×).
- `basis:` on each cost session; `calibration` flags bands that mix bases.
- `task.verify_rounds` keeps every verify outcome. irradiance's pushback count
  went from 1 spec to 6.

### 7. Update channel (v0.6.49)

- `just template-update <instance>`, run from the template repo: a three-way
  merge per template-managed file, dry run by default. It never writes a
  conflict or an instance-owned file (`AGENTS.md` and the like), and it holds
  back every script change when `_lib.sh` can't be updated.

## Rollout to instances

| Instance | State |
|---|---|
| diamond-exif | Updated to 0.6.49 (jysf/diamond-exif#30, merged) |
| irradiance | jysf/irradiance#164 open, CI green; `_lib.sh` hand-merged, keeping its own functions |
| standup | Not yet; update when convenient |
| crustyimg | Not yet; active, update at a natural pause. No `VERSION`, so needs `--base` |
| zany, bragfile | Inactive; update if work resumes. No `VERSION` |
| grebe, skillport | Inactive; not updating |

The rule: update an instance when work on it resumes, not before. The tool
handles a multi-version jump in one run, so waiting costs little.

## Still open

- `template-update` can't accept a `_lib.sh` you resolved by hand, so the
  rollout needed manual steps. Fix before the next instance.
- Policy: the DEC namespace collision; DEC-022's orchestration-cost gate;
  DEC-014's open questions.
- Batch 5 leftovers: `new-project`, a `calver` default, a `no-auth` seed
  constraint, a check that a DEC's referents still exist.
- `decisions-audit` takes about 4 minutes on crustyimg.
- `just id-audit` exits 1 on diamond-exif (SPEC-004 used twice across branches);
  real data, not in CI.
