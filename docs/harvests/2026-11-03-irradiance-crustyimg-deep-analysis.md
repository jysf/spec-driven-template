# Harvest 2026-11-03 — irradiance + crustyimg, and the case for a compiled `sdt`

Template at **v0.6.39** (no release since 2026-08-16). Sources, all fetched from
GitHub before reading:

- **irradiance** (claude-plus-agents, scaffolded 0.6.38) — `guidance/signals.yaml`,
  `AGENTS.md` §§4/6/8/11–13/15/16, `guidance/constraints.yaml`, PATCH-001..004,
  `feedback/2026-08-15-*`, `2026-09-06-*`, `2026-11-03-*`, the 8 differing + 6
  instance-only scripts. (`throwaway-irradiance` is a stale ancestor checkout,
  21 commits behind — not used.)
- **crustyimg** (claude-only) — `docs/framework-feedback/{2026-11-signals-since-v0.8,
  tooling-that-fails-silent, signals-harvest, process-feedback}.md`,
  `feedback/2026-08-11-crustyimg-process-analysis.md`, every `scripts/` commit.
- **bragfile000**, **zany-animal-slots** — feedback, every `scripts/` commit,
  front-matter of all specs.
- Template `feedback/` holds only the four July rounds, all still `status: open`
  although the 2026-07-06 harvest triaged them. Everything since August lives only
  in the instances.

Method: three read-only research passes, then the load-bearing claims re-run by
hand. Every count below was produced by parsing, not recalled.

---

## Part 1 — irradiance against template HEAD

**Nothing irradiance reported is fixed upstream.** Every finding post-dates the
last template release. Status per item:

| # | Item | HEAD | Notes |
|---|---|---|---|
| 1 | `gate-audit.sh` + red-proof (mute-death scan) | OPEN | Engine is **Ruby**. SPEC-023 found 3 reachable offenders; only `decisions-audit.sh:217` (DEC with no H1) can actually kill a template run. Guards inside functions called via `$()` are no-ops (bash drops `set -e` there — re-verified on 3.2) |
| 2 | Real YAML parse gate in `validate` + red-proof + `SPEC-900` fixture | OPEN | Template validate is keys-only. **Template CI never runs `validate` at all** (`ci.yml` runs only cost-audit + decisions-index) — that is how irradiance's unparseable handoff got through. Fixture can't be ported without the `next_id` tests/ fix |
| 3 | `cost-audit-red-proof` + DEC-022 stage `orchestration_cost` gate | OPEN — **conflicts** | Template deliberately keeps orchestration outside the gate (CHANGELOG v0.6.33, `test.sh:2695`). Porting needs a template DEC, not a copy. Red-proof uses python3, hard-codes STAGE-001/002 |
| 4 | §15 `SB-N`/`FU-N` ids, `## Follow-ups` table, reflection-unfilled gate | OPEN | Irradiance hasn't built the gate either ("What enforces this today: nothing") |
| 5a | handback-sync multi-line scalar truncation | OPEN | One-line reader + raw unquoted writer. Irradiance only *detects* it (parse gate) |
| 5b | quoted-`#` truncation | OPEN | `_lib.sh:292/310/327`. Irradiance fixed the handback reader only; handoff + spike readers still carry it |
| 5c | unquoted-`#` truncation | **not a bug** | Correct YAML: ` #` starts a comment; a real parser truncates identically. Writer contract issue. (Latent real bug: the regex also strips `foo#bar`, which YAML keeps) |
| 5d | superseded handoff blocks sync | OPEN (fixed in irradiance) | Also add `superseded` to `handoff.md` status vocabulary |
| 5e | stale `to_agent` across punch-list rounds | OPEN everywhere | Stamped from the tier_map *prediction*; handback has no field for the model that actually ran |
| 5f | cost field has two owners → double append | OPEN everywhere | §15 tells agents to append; handback-sync appends too, idempotence keyed on `synced_at` only |
| 6a | `next_id` collides across branches/worktrees | OPEN | |
| 6b | `next_id` scans `tests/` | OPEN (inline fix in irradiance, no test) | |
| 7 | JSONL metering: `message.id` dedup, per-component pricing, orchestrator exclusion | OPEN — **nowhere** | Not codified even in irradiance's AGENTS §4; lives only in signals. crustyimg's `docs/cost-tracking.md` has the corrected method + max-output rule + worktree/subagent dirs |
| 8 | §16 four codified rules | PARTIAL | Rule 4 (unrun docs) ≈ template v0.6.37 rule 1. Rules 1–3 absent; all generic |
| 9 | `oracle-must-be-shown-red` constraint | OPEN | Generic. `provenance-ledger.md` is domain-specific (RAW/copyleft) — not a template default |

Also open and template-owned: cost-audit scoped to the active project (both
repos, independently); `brag` step skipped at ship; desktop sessions have no
`/cost`; flat `rate_per_mtok` overstates cache-heavy sessions; `verify_verdict` is
**last-write-wins** (`advance-cycle.sh:84`) — irradiance's field shows 1 punch-list
in 33, its artifacts show 5.

### The 2026-08-15 scaffold findings (not in the list above, all still OPEN)

`just init` one-shot + destructive; no `just new-project`; `calver` default wrong
for libraries; example DEC/project survive and `decisions-audit` passes a DEC
citing a deleted constraint; ~4,800 lines of maintainer content ship per instance;
template and instance DEC ids collide (`DEC-001` names two files); bare-name
`affected_scope` warns on correct root-level files; `frame-stage` slug uncapped;
`(not yet written)` survives when no dash follows it. Win (N=1, capture only):
the spike lane beat an independently-designed STAGE-000.

### Numbers in the brief that don't match the source

- "36 signals / 36 DECs" → **34 signals** (20 process-debt, 9 lesson, 3 golden-path,
  2 risk) and **34 DEC files** (DEC-000..034, no 001).
- "next_id N=4 in one day" → the signal says 1 on 08-22 + 3 on 09-06. Two more in
  the 08-15 feedback (HANDOFF-008/009). **One more found in git:** DEC-028 minted on
  two branches on 2026-10-28 (`b4a2793` vs `cac2e05`). True N ≥ 7, and the signal's
  "none ever reached history" is now false.
- The 09-06 feedback argues `git log --all` minting "would not have caught either
  instance" because both were uncommitted — its own table says HANDOFF-038 was
  committed and pushed. Ref-aware minting would have caught at least 3.
- "Dedup fixes 1.7×" → measured 1.76–2.25×.
- "tier_map 0 for 7" → the signal contradicts itself (header "0 for 7", body lists
  6 misses, ends "1 for 7", notes "1 for 4"). Directionally right; not a number.
- "a-gate-that-fails-mutely" N=4 → 3 of the 4 are wrong-text matches in Rust
  source; one (PATCH-001, ANSI-coloured clippy) is the pipefail shape, and it was in
  irradiance's own Rust gate, not a template script.

### crustyimg's 2026-11-02 signals (new, not yet in the template)

`find_spec` still matches `specs/prompts/` *in crustyimg* (fixed upstream in
v0.5.19 — drift); inline-array `affected_scope` silently dropped, and the
template's own `decisions/_template.md` teaches that form; `just backlog` ignores
`proposed` projects (54 items invisible); spec template lacks a file inventory;
`just check` weaker than CI; DCO sign-off missing on verify commits (4th time);
plus seven verify/build lessons, three at N≥3 (`measure-the-scenario-not-the-control`,
`derived-value-needs-a-differing-input`) and `a-document-is-not-a-backlog` (4 cases,
13 days lost). Same-outcome with irradiance: **cost method** (both repos
independently found the ~2× JSONL inflation) and **cost-audit active-only**.

---

## Part 2 — the case for a compiled `sdt` (CLI + MCP)

### Root-cause tally

Deduplicated across all four repos plus the template's own CHANGELOG. 77 rows from
crustyimg/bragfile/zany/template, 39 from irradiance (counted separately; small
overlap). Buckets as defined in the brief:

| Bucket | Other repos (77) | irradiance (39) | Combined |
|---|---|---|---|
| A — line-oriented YAML/markdown parsing | 10 | 5 | 15 (13%) |
| B — pipefail / zero-match / ANSI / locale / BSD | 11 | 7 | 18 (16%) |
| C — working tree instead of git refs | 4 | 1 | 5 (4%) |
| D — JSONL metering method | 4 | 2 | 6 (5%) |
| E — fix not propagated | 5 | 1 | 6 (5%) |
| F — design/semantics (any language) | 43 | 23 | 66 (57%) |

Counterfactual — would a typed implementation have **prevented** it by construction:
**24 of 116 (21%)**; made it **less likely**: 11 (9%); **no effect**: 81 (70%).

What the numbers mean:

1. **The most expensive incidents are all F or E**, and a rewrite prevents none of
   them: 35 backlog items invisible for months (prose-keyed counter); specs stuck at
   the wrong cycle (glob scope); the decision-drift gate that could never fail
   (`--changed` on a clean tree); every command targeting the shipped wave (resolver
   ignoring status); duplicate IDs; unusable cost data; features never reaching
   instances.
2. **Most of what Rust *would* prevent was loud** (exit 1/141, mojibake) and fixed
   in-session. The silent exceptions are the A bucket's worst rows: the 87%
   understated `cost.totals`, SPEC-010 shipping unparseable front-matter with every
   gate green, `update_frontmatter_scalar` reporting "recorded" while writing
   nothing, inline-array `affected_scope` dropped.
3. **C and D are choices about which data to read, not language features.**
   `git for-each-ref` / `git log --all` is as available to bash as to git2; message-id
   dedup is domain knowledge either way.
4. **B is overstated by the brief's framing.** Of irradiance's 7 B items, 2 were
   observed failures; the rest are latent or cannot fire.
5. **Drift is the multiplier on everything.** Script byte-identity with HEAD:
   crustyimg 1/23, bragfile 1/16, zany 2/21, irradiance 38/52. Every `_lib.sh` has
   forked. Bugs fixed upstream hit instances months later (`find_spec`, `done/done/`,
   per-project `next_id`, missing-dir `cp`), and `get_active_project`, `next_id`
   and the pipefail exits were each re-fixed independently in 2–3 repos.

### The two facts that *do* argue for a typed core

- **irradiance has already abandoned zero-dependency bash** to get correct
  front-matter handling: Ruby in `validate` and `gate-audit`, python3 in the
  cost-audit red-proof. The constraint is being broken in practice, exactly where
  bucket A lives. That is the strongest evidence in the corpus, and it is
  specific to A.
- **The template can't currently tell an instance it is behind** in a way that
  results in an upgrade. A versioned binary + `brew upgrade` is one way to ship a
  fix to every repo at once — but that is a property of shipping a versioned
  artifact, not of the language. A `just template-update` that pulls a tagged
  `scripts/` tree gets most of it, and v0.6.38's `just instances` already reports
  who is missing what.

### If a binary is built — architecture notes

- **brag is Go, not Rust** (cobra + `modelcontextprotocol/go-sdk` + pure-Go sqlite;
  goreleaser → `jysf/homebrew-tap`; `brag mcp serve` wraps the same `Store` the CLI
  uses; an import-audit test enforces the layering). Its pattern transfers; its MCP
  code transfers only to a Go `sdt`. No Rust MCP precedent exists in `~/PSeven`.
  crustyimg's cargo-dist + tap config is the Rust distribution precedent.
- **Comment-preserving YAML edits favour Go.** The template's artifacts carry
  legend comments (`# completed | blocked | rejected`) that agents read. `serde_yaml`
  round-trips drop every comment; Rust has no mature comment-preserving editor. Go's
  `yaml.v3` `Node` API keeps head/line/foot comments. A Rust port would need
  span-based surgical edits (parse to locate, splice text) — doable, but it is the
  same hand-rolled editing that bucket A is about.
- **What moves into the binary:** front-matter parse/validate/upsert on a real AST;
  ID minting from all refs + worktrees + an append-only claim ledger; transcript
  metering (dedup by `message.id`, max output, per-component pricing, worktree and
  subagent dirs, orchestrator exclusion); the `--json` read commands (already a
  contract — DEC-001 makes binary/front-matter version skew testable); gates;
  `sdt upgrade` that rewrites the instance's scaffold to a tagged version.
- **What stays in `just`:** `app.just` (the app's own recipes), thin `justfile`
  dispatch to `sdt`, CI wiring.
- **What it costs:** breaks "zero runtime deps / bash 3.2" (the template's headline
  constraint); adds binary↔artifact version skew; `test.sh`'s 2,870 lines of
  end-to-end assertions must be re-pointed; reverses `CONTEXTCORE_ALIGNMENT.md`'s
  "No MCP server wrappers"; and a rewrite of 11.5k lines carries its own regressions
  in the exact tools a memoryless agent trusts to describe the repo.

### Recommendation

**Don't rewrite now; the measured pain doesn't support it.** Do the three things
that address 80% of the tally regardless of language, and pre-register the
condition under which the binary becomes the right call:

1. **Fix the open bugs in bash** — most are one-liners already written in some
   instance (list in "First batch" below).
2. **Make silence loud + test the numbers.** A fixture project in `test.sh` with
   known counts (backlog items, active stages, cycle, verdict history) would have
   caught crustyimg's worst five. "I found none" vs "my pattern matched nothing".
3. **Ship an update channel** (`just template-update` from a tagged release, reusing
   `just instances` to report drift). This is the E-bucket multiplier.

**Pre-registered trigger for `sdt`:** if, in the next two instances' first
projects (post-update-channel), (a) another instance adds a non-bash runtime to get
correct front-matter handling, **or** (b) A-bucket silent corruption recurs (a gate
green on an artifact a YAML parser rejects), build the typed core — front-matter
read/write + ID minting + metering first, behind the existing `--json` contract,
CLI before MCP. Language: Go if comment-preserving edits and brag reuse matter
most; Rust if crustyimg's dist pipeline and the owner's Rust fluency do. Write it as
a DEC either way, since it reverses the zero-dependency position.

---

## Part 3 — what the corpus can prove, and the ContextCore boundary

### What survives checking (371 specs parsed, 0 YAML errors)

| Claim | Evidence | Grade |
|---|---|---|
| **Decisions are reused** | Specs citing ≥1 DEC: crustyimg 99%, zany 100%, bragfile 93%, irradiance 83%; **0 dangling in 1,402 citations** | usable — but citation is prompted, so it proves reference, not use |
| **Independent verify sends work back** | crustyimg SPEC-061+: ~39% (SPEC-001–060: 0% — a recording era, not a quality era); irradiance 5/33 (15%) | usable-with-caveats |
| **Verify that never rejects is a failure signature** | zany: verify approved 103/103; users then found ≥4 real defects | usable — the cleanest paired result in the corpus |
| **Verify catches neighbours' escapes** | crustyimg: 6 escapes found by *another* spec's verify | usable-with-caveats |
| **S/M/L weakly predicts cost within one metering regime** | Spearman ρ 0.42 (crustyimg measured), 0.55 (irradiance), 0.54 (zany); ranges overlap heavily | usable-with-caveats; pooled crustyimg ρ = −0.01 |
| Cross-repo cost / unit economics | 100–200× gaps between cache-inclusive and exclusive regimes; zany flat-rate USD; `estimate_basis` used 0 times; bragfile has no cost data | **not comparable** |
| `verify_verdict` as a send-back rate | last-write-wins scalar; ~5× undercount in irradiance; present in 1 instance | **not usable** |
| Value thesis | `value_realized` null in every brief | **no data** |
| irradiance clean-room provenance | 17-row ledger, 15 class-1; maintained by process, nothing mechanically checks it against `src/` | usable-with-caveats (self-attestation) |

The defensible headline today: **the decision log compounds, and an independent
verify that is allowed to reject finds things a builder doesn't — the one repo where
it never rejected shipped defects users found.** Cost and calibration claims are
not publishable (see also the 2026-08 note that SPEC-108 still holds a known-wrong
figure).

### To make it provable on the next projects (forward-only, all template-side)

- `verify_rounds[]` (verdict history) instead of a scalar `verify_verdict`.
- Cost sessions carry `basis:` (`transcript-deduped` | `agent-result` | `estimate`)
  and split `input/output/cache_read/cache_creation`; price per component.
- Record the **actual** model per session (from `message.model`), not the tier_map
  prediction.
- `type: bug` specs carry a structured `introduced_by: SPEC-NNN` (escapes are
  recoverable today only from prose).
- crustyimg's pre-registered predictions (§9 of its 08-11 analysis) are the right
  shape: lesson reach >80% within one project if given a `references.lessons` slot;
  class-A (cross-product) defects drop, class-B do not.

### The boundary with ContextCore

`CONTEXTCORE_ALIGNMENT.md` already draws it: the template borrows the vocabulary
(`task.*`, `project.*`, `insight.*`, …) and does **no** spans, dashboards, CRDs or
MCP. DEC-001 makes `--json` emit CC/OTel attribute names; DEC-002 (proposed)
positions `cost.*` as an upstream candidate. The evidence above suggests sharpening
it to:

| `spec-driven-template` (standalone, per repo) | ContextCore (cross-repo, commercial) |
|---|---|
| Artifacts + schema + gates that keep each record honest at write time | Aggregation across repos and teams |
| Single-repo `--json` read contract (the handoff surface) | Normalising cost regimes, pricing, model mix into unit economics |
| Measured-vs-estimate tagging *at capture* | Cross-repo decision enforcement (DEC → scope → change), drift alerts |
| Verify verdict history, escape lineage, as fields | Quality telemetry over time, benchmarks between teams |

The rule that keeps it clean: **anything needed to make a single repo's record
true belongs in the template; anything that only has meaning across repos belongs
in CC.** Every forward fix in the list above is the first kind — none of it needs
CC to exist.

Two things to check before leaning on this boundary: `CONTEXTCORE_ALIGNMENT.md` is
stale (no `cost.*`, `verify_verdict`, `orchestration_cost`, `value_realized`), and it
links a public GitHub ContextCore repo, which conflicts with "closed-source".

---

## First batch (proposed)

> **Done, 2026-11-10:** all seven shipped as v0.6.40–v0.6.49. What each one
> changed, and where the instance rollout stands, is in
> [`2026-11-10-harvest-outcome.md`](2026-11-10-harvest-outcome.md).

Ranked by severity × cost; each has a reference fix in some instance.

1. **Corruption fixes:** quoted-`#` strip in all three readers; multi-line scalar
   write (quote/escape in handback-sync); handback-sync idempotence keyed on the
   data (cycle already in `cost.sessions`), and §15 says "fill the handback; the
   orchestrator syncs".
2. **Gate that can't fail → can:** add `validate` to template CI; port the parse
   gate + red-proof (needs the dependency decision — Ruby/python3 are not allowed
   today); `decisions-audit --changed` falls back to `main...HEAD` on a clean tree
   (crustyimg 67cd4f6).
3. **IDs:** `next_id` excludes `tests/` and scans all local refs + worktrees, plus an
   `id-audit` across refs; decide whether to add the append-only ledger.
4. **Silent-zero tooling:** structure-keyed backlog counter shared in `_lib`
   (crustyimg 6b26006), plural active stages, `find_stage` exclusions, archive-spec
   reports remaining backlog, `backlog` sees `proposed` projects, inline-array
   `affected_scope` parsed + `decisions/_template.md` fixed, `new-spec` missing-dir
   guard (bragfile a015a5f), archive-spec while-loop (BSD xargs).
5. **Scaffold:** `scaffold-clean` removes `*example*` project/DEC + maintainer docs;
   bare root-level `affected_scope` no longer warns; frame-stage slug cap + marker
   strip; `just init <variant>` with confirmation; `is_grandfathered_cost` accepts
   `PATCH-` ids (template `_lib.sh:1014` hardcodes `SPEC-`, so a patch can never be
   grandfathered — fails closed, but unusable; irradiance bc12e1f is the fix).
6. **Cost method** written into AGENTS §4 + handoff template (dedup, max output,
   per-component, worktree/subagent dirs, orchestrator exclusion) and a `basis:`
   field; `verify_rounds[]`.
7. **Update channel** (`just template-update`) — so batches 1–6 reach crustyimg,
   irradiance and diamond-exif by a version bump.

Policy calls needed from the owner before porting: the orchestration-cost gate
(DEC-022 vs template's documented choice); any non-bash dependency; the DEC
namespace collision (rename template DECs to `TPL-NNN` or move the directory).

---

## Addendum — second pass on the same prompt (2026-11-03)

A second copy of the prompt named the same files; re-checked against irradiance
`main` @ 2b6b07a (up to date with origin). Everything it lists is covered above.
Two findings were not:

**1. Irradiance's own cost gate is green over three zero-cost patches.**
PATCH-002, -003 and -004 sit in `patches/done/` with `sessions: []` and
`tokens_total: 0`; `just cost-audit` exits 0 because all three were added to
`COST_AUDIT_GRANDFATHERED` (irradiance bc12e1f, 2026-09-06). The list's own comment
says it exists for gates "adopted after already shipping"; these patches shipped
*after* the gate — two of them built it. The stated reason ("PRs merged manually
without formal verify handbacks") is false for two of three: HANDOFF-039
(PATCH-002 verify) and HANDOFF-040 (PATCH-003 verify) are `completed` with
`tokens_total` 10.3M and 7.5M and `synced_at: null` — the data exists and one
`handback-sync` would have recorded it. Only PATCH-004's verify (HANDOFF-042) never
ran; it is still `pending`, so PATCH-004 shipped with no independent verify.

Template implications:
- A grandfather list is an un-gated bypass. `cost-audit` should warn when a
  grandfathered id's `created_at` is later than the gate's adoption, or when a
  completed-but-unsynced handoff exists for it ("cost is recoverable — run
  handback-sync").
- `archive-patch` (and `archive-spec`) should refuse when the verify handoff is
  still `pending` — the patch lane's one promise is that verify is KEPT. This is the
  refuse-rarely precedent: the missing thing *is* the failure.
- This is a fourth instance of "a gate that fails mutely": not a pipefail death but
  a gate whose escape hatch was used silently. Counts toward bucket F (design), not
  a rewrite argument.

**2. Heading/id mismatch passes `validate`.** PATCH-004's file has `id: PATCH-004`
but its H1 reads `# PATCH-003: …` (copied from its predecessor). Neither template
nor irradiance `validate` compares the H1 id to `task.id`. Cheap advisory check;
fits the "warn by default" rule.

**Generalisable from PATCH-004 itself:** irradiance now has five `*-red-proof.sh`
scripts (validate, lint, lint-fuzz, gate-audit, cost-audit), and PATCH-004's lesson
is that a red-proof must also *name the tool that produced its result* — a bare
`cargo clippy` resolved to Homebrew's binary and passed silently. Template form:
every gate prints the version of the external tool it shelled out to. Domain-
specific in detail, N=1 as a template rule; record, don't codify yet.

