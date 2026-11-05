---
insight:
  id: DEC-014
  type: decision
  confidence: 0.7
status: accepted            # proposed | accepted | superseded
created_at: 2026-11-05
deciders: [jysf, claude]
supersedes: null
superseded_by: null
affected_scope:
  - "scripts/validate.sh"
  - "scripts/_lib.sh"
  - "scripts/handback-sync.sh"
  - "scripts/advance-cycle.sh"
tags: [architecture, tooling, distribution, yaml, mcp, go]
---

# DEC-014: a typed core, when built, is an optional Go binary (`sdt`)

> **This is the template's own decision log** (meta), separate from the
> `decisions/` that ships *inside* each variant. **Accepted 2026-11-05.**

## Context

The 2026-11 harvest
([`2026-11-03-irradiance-crustyimg-deep-analysis.md`](../harvests/2026-11-03-irradiance-crustyimg-deep-analysis.md))
tallied 116 recorded bugs across four instances. A typed rewrite of `scripts/`
would have prevented about 21% outright. That is too little to justify a
rewrite as a *bug fix* — 57% are design bugs that would exist in any language.

Two things changed the question anyway:

1. **Bash cannot read the file format.** Irradiance had to add Ruby (in
   `validate` and `gate-audit`) and python3 (in a red-proof) to get front matter
   parsed correctly — after a spec shipped with front matter no parser could
   read while every gate passed. v0.6.40 fixed the worst line-stripping in the
   template, but a line-oriented reader is still guessing at YAML. The harvest
   pre-registered this as a rewrite trigger: *an instance adds a non-bash runtime
   to handle YAML.* It fired.
2. **A binary is also the missing update channel.** Instances copy `scripts/`
   at scaffold time and never receive fixes (crustyimg shares 1 of 23 scripts
   with the template). A binary installed from a Homebrew tap updates every
   instance at once with `brew upgrade`. Valued as distribution, not just bug
   prevention, the case is much stronger than 21%.

## Decision

**When the template needs a typed core, it is a single Go binary, `sdt`,
adopted incrementally and always optional.**

1. **Go.** Built and released the way `brag` (bragfile) already is: Cobra CLI,
   the official MCP Go SDK for `sdt mcp serve`, goreleaser, the
   `jysf/homebrew-tap` tap.
2. **Only for what needs it.** No big-bang rewrite. The first commands are the
   ones bash is worst at:
   - `sdt validate` — a real YAML parse of every front-matter block.
   - `sdt fm get|set` — read and edit front matter **without losing comments**.
   - `sdt template-update` — bring an instance's shipped files up to date.

   Further commands move over only when a harvest shows bash failing at them.
3. **Optional, with a fallback chain.** A script that can use `sdt` tries, in
   order: `sdt` if installed → `ruby` (YAML is in its standard library) if
   installed → the bash implementation, with a warning that the check is
   weaker. A repo without `sdt` keeps working. The standalone rule holds: the
   template still installs nothing, and still never depends on ContextCore.
4. **The contracts do not move.** Artifacts stay plain git-native Markdown with
   YAML front matter. `--json` output keeps DEC-001's envelope and exit codes
   (`0` ok, `1` gate failure, `2` usage error). A command ported to `sdt` must
   produce the same output as its bash version, and `test.sh` asserts that.

## Alternatives considered

- **Rust.** Small binaries, and crustyimg/irradiance are Rust. Rejected on the
  deciding requirement: commands like `advance-cycle` and `handback-sync` edit
  heavily-commented front matter in place, and Rust has no maintained YAML
  library that preserves comments on round-trip (`serde_yaml` is archived and
  drops them). Sharing code with the Rust instances is not a need.
- **TypeScript compiled with Bun or Deno.** The `yaml` package preserves
  comments well and the MCP TypeScript SDK is the reference implementation.
  Rejected for binary size (50–90 MB) and no existing release pipeline.
- **Python.** No YAML in the standard library, and packaging a dependable CLI
  is the weakest of the options.
- **Stay pure bash.** Rejected as the long-term answer for parsing and for
  distribution. Kept as the fallback in the chain above.
- **Make Ruby a hard requirement.** Rejected: macOS's system Ruby is
  deprecated, and its YAML API changes between versions (irradiance hit
  `safe_load(permitted_classes:)` failing on 2.6 in a way that looked like a
  finding). Fine as an optional middle step, not as a foundation.

## Consequences

- **Positive:** correct YAML handling where it matters most; comment-safe edits;
  a real update path to existing instances; an MCP surface for agents, reusing
  brag's patterns.
- **Negative:** two implementations of each ported command until bash is
  retired for it, so behaviour can drift between them. The parity assertions in
  `test.sh` are the guard; a port without them is not done.
- **Reverses a stated position:** `docs/CONTEXTCORE_ALIGNMENT.md` (shipped in both
  variants) says "No MCP server wrappers". It must be updated when `sdt mcp serve` lands.

## Open questions (settle before the first `sdt` spec)

- **Where the source lives:** this repo (e.g. `cmd/sdt/`) or its own repo.
- **Version coupling:** how `sdt` knows which template version an instance was
  scaffolded from, and what it does when the two disagree.
- **YAML library:** the original `gopkg.in/yaml.v3` repo has been archived.
  Confirm which maintained successor is current when the first spec is written.

## Revisit when

- The first three commands ship and a harvest shows whether instances actually
  installed `sdt`, or kept running the bash fallback.
- Any instance needs Windows support (not a target today).
