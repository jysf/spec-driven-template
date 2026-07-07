---
insight:
  id: DEC-010
  type: architecture
  confidence: 0.8
status: accepted            # proposed | accepted | superseded
date: 2026-07-06
deciders: [jysf, claude]
supersedes: null
superseded_by: null
affected_scope:
  - "variants/*/.repo-context.yaml"
  - "variants/*/guidance/recommended-tools.md"
  - "variants/*/AGENTS.md"
  - "scripts/log-accomplishment.sh"
  - "scripts/_lib.sh"
  - "justfile"
tags: [architecture, value, accomplishments, brag, ship]
---

# DEC-010: accomplishment logging on by default (via `brag`)

> **This is the template's own decision log** (meta). **Status: accepted —
> shipped in v0.6.10.** Reverses the earlier "keep it out of the template
> defaults" stance for accomplishment logging.

## Context

The template already told agents to log a shipped win *with impact* at ship, but
framed it as **optional** and "keep it out of the template defaults" — so it kept
getting skipped (including on the template's own work this session). Meanwhile the
default tool, [`brag`](https://github.com/) (a local-first CLI + MCP server for
capturing career accomplishments), is a first-party tool here and one of the
dogfood projects — and it has exactly the right seam: `brag add -i "<impact>"`,
`brag mcp serve`, and per-directory project auto-fill. Impact capture is also the
outward form of the value the template *already* records (`value_link`,
`cost.totals`), so making it default-on is nearly free and closes the loop from
"we tracked value" to "we can report it."

## Decision

**Accomplishment logging is on by default**, tool-configured (default `brag`).

- **Config:** `.repo-context.yaml` → `spec.accomplishments` (`enabled: true`,
  `tool: brag`, `interface: cli | mcp`). Set `enabled: false` to opt out; swap
  `tool` for an equivalent. Keeps the template tool-agnostic at the core while
  defaulting to the first-party tool.
- **`just log-win SPEC-NNN`** (`scripts/log-accomplishment.sh`;
  `get_accomplishments_field` in `_lib.sh`) pre-fills the entry from the spec's
  **title + `value_link` + `cost.totals`** (framing value-per-dollar), then runs
  `brag add` if `brag` is present, else prints the ready command. Degrades
  cleanly when the tool is absent or disabled.
- **Both interfaces documented:** the `brag` CLI (`brag add`, scripted `--json`
  mode safe for a sub-agent) and the MCP server (`brag mcp serve` → `brag_add`).
- **AGENTS "During ship"** (both variants) now says *log the win* (default-on),
  not *optionally log it*.

## Alternatives considered

- **Keep it optional** (status quo) — rejected: it kept being skipped, and the
  impact record is the payoff of the value/cost tracking the template already does.
- **Hard-wire `brag` with no config** — rejected: the template serves other
  users; the config keeps it swappable / opt-out while defaulting to brag.
- **A cost-audit-style gate** — rejected: impact framing is judgment-laden and
  personal; a convention + a one-command helper is the right weight (a gate would
  punish honest "nothing brag-worthy" ships).

## Consequences

- Every shipped spec/stage/project gets a one-command path to an impact-framed
  brag entry, auto-seeded from data already in the spec.
- One config key + a small helper + a `just` recipe to maintain (all degrade if
  `brag` is absent, so a non-brag user is never blocked).
- Reinforces the value loop: `value_link` → `just log-win` → a portable brag
  entry that can feed retros/reviews/résumés.

## Open questions

1. **Auto-run at `archive-spec`?** `log-win` could fire automatically at ship
   rather than as a separate step. Kept separate for now (an explicit, editable
   impact line beats an auto-generated one).
2. **MCP-first for delegated agents** — when a build/verify sub-agent ships, is
   `brag mcp` the cleaner path than shelling out to the CLI? Revisit with the
   sub-agent delegation work (DEC-004).
