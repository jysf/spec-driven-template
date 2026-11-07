# Projects built with this template

Real projects scaffolded and run with this spec-driven template. Each
one is also a feedback source: friction found while shipping it has
driven concrete template changes (see `CHANGELOG.md` and `feedback/`).

> Built something with this template? Add a row — repo, one line on what
> it is, and the variant you used.

## bragfile

A command-line tool for logging your accomplishments (the "brag file"),
written in Go. Built as `PROJ-001` and shipped to a Homebrew tap.

- **Repo:** <https://github.com/jysf/bragfile000>
- **Variant:** `claude-only`
- **Scale at MVP:** 5 stages, 23 specs, 14 decisions, ~4 weeks.
- **Template feedback it produced:** `feedback/2026-04-20-bragfile-project.md`.
  The `just specs-by-stage` ledger (v5.6) was back-ported *from* this
  project; the v5.8 substitution-escaping fix is the same bug class
  flagged in its process feedback.

## rspeed

A cross-platform network-speed CLI written in Rust, with multi-OS CI
(Linux/macOS/Windows green in ~1m16s warm-cache). Built stage-by-stage
on the same frame → design → build → verify → ship cycle.

- **Variant:** `claude-only`
- **Notable:** planning baseline opened with 8 ADRs; first user-facing
  CLI landed with 11 cross-platform tests passing.

## crustyimg

A single-binary image CLI in pure Rust: make an image web-ready in one
command, with a real quality score instead of a guessed quality number.
The largest instance by far.

- **Repo:** <https://github.com/jysf/crustyimg>
- **Variant:** `claude-only`
- **Template feedback it produced:** `feedback/2026-07-03-crustyimg-proj-001.md`,
  its own `docs/framework-feedback/`, and the
  [2026-11-03 harvest](docs/harvests/2026-11-03-irradiance-crustyimg-deep-analysis.md).

## zany-animal-slots

A play-money, mobile-first web slot game with a config-driven
engine/presentation split. [Play it](https://zany-animal-slots.jysf.org).

- **Repo:** <https://github.com/jysf/zany-animal-slots>
- **Variant:** `claude-only`
- **Template feedback it produced:** `feedback/2026-07-03-zany-animal-slots-proj-001.md`;
  the `lifetime-report` data/prompt split (v0.6.17).

## skillport

A Rust tool that lints and audits agent Skills (`SKILL.md` files) against
the open Agent Skills spec.

- **Repo:** <https://github.com/jysf/skillport>
- **Variant:** `claude-only`
- **Template feedback it produced:** the spec-title ledger (v0.6.22) and
  the Reflection-Q5 answer slot (v0.6.24).

## irradiance

A pure-Rust library that reads camera RAW files and develops them into
images: sensor data in, pixels and metadata out.

- **Repo:** <https://github.com/jysf/irradiance>
- **Variant:** `claude-plus-agents`
- **Template feedback it produced:** the
  [2026-11-03 harvest](docs/harvests/2026-11-03-irradiance-crustyimg-deep-analysis.md);
  repeated id collisions across branches led to cross-branch id minting
  and `just id-audit` (v0.6.45).

## diamond-exif

A panic-free, pure-Rust EXIF/XMP/IPTC/ICC metadata reader, writer and
stripper for server-side workloads, checked against ExifTool.

- **Repo:** <https://github.com/jysf/diamond-exif>
- **Variant:** `claude-plus-agents`

## The template itself

The template is not built *with* its own spec process — it predates a
spec-driven repo of its own. Its evolution from the v5 baseline through
v5.8 is recorded in `CHANGELOG.md` and git history, not in `SPEC-*`
files. The specs that *this template produces* live in the downstream
project repos above (e.g. browse `projects/` in bragfile000 to see real
specs, stages, and decisions in the wild).
