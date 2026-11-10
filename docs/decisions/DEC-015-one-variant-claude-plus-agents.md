---
insight:
  id: DEC-015
  type: decision
  confidence: 0.7
status: accepted            # proposed | accepted | superseded
created_at: 2026-11-10
deciders: [jysf, claude]
supersedes: null
superseded_by: null
affected_scope:
  - "scripts/init.sh"
  - "justfile"
  - "README.md"
  - "variants/claude-plus-agents/AGENTS.md"
  - "variants/claude-plus-agents/GETTING_STARTED.md"
  - "variants/claude-plus-agents/README.md"
  - "variants/claude-plus-agents/projects/_templates/spec.md"
tags: [architecture, variants, delegation, handoff, scaffold]
---

# DEC-015: new instances use claude-plus-agents; claude-only is deprecated

> **This is the template's own decision log** (meta), separate from the
> `decisions/` that ships *inside* each variant. **Accepted 2026-11-10.**

## Context

The template has shipped two variants since the start. They run the same cycle
and the same scripts; they differ in who runs build and verify and where the
build context lives:

- **claude-only**: the session that designed the spec also builds and verifies
  it. Build context is a `## Implementation Context` section inside the spec.
- **claude-plus-agents**: each delegated cycle gets a `HANDOFF-NNN` file, the
  agent that runs it fills a `handback:` block (verdict, model, measured cost),
  and `just handback-sync` copies that into the spec.

Measured on 2026-11-10 against `variants/`: claude-plus-agents carries every
file claude-only does, plus `projects/_templates/handoff.md`; 31 of the 45
shared files are byte-identical. Every script is shared.

The variant docs framed claude-plus-agents as "a different tool implements"
(Kilo, Cursor, …) and told an unsure user to start with claude-only. That is
not how it has been used. Its two active instances ran build on **Claude**
subagents, through handoffs, for nearly every spec: irradiance 50 of 55,
diamond-exif 20 of 22 (the rest were in flight).

And the handoff earns its cost even when every agent is Claude:

- **Build starts from a clean context** holding only what design wrote down, so
  missing context shows up as a question instead of being silently supplied by
  the designer's memory.
- **Verify stays independent** of the build session, which AGENTS.md already
  requires for patches and which is the one discipline the dogfood showed
  catches defects.
- **Cost is measured per cycle by the agent that ran it** (DEC-013), with the
  model that actually ran (`handback.agent`) and how it was measured
  (`handback.basis`). In claude-only, cost comes from one session's memory.
- **Every verify outcome is on record** (`handback.verdict`, `verify_rounds`).
  On irradiance the handoffs show 6 specs sent back where the spec field alone
  showed 1.

Maintaining two variants also costs every change twice. The parity rule ("a
change to shipped content is two edits") is this repo's most common mistake.

## Decision

1. **New instances use claude-plus-agents.** `just init` lists it first and
   marks it recommended; pressing Enter picks it.
2. **claude-only is deprecated, not removed.** `just init claude-only` still
   works and prints a deprecation notice. The files stay under `variants/`
   because six instances use it (bragfile, crustyimg, zany, rspeed, skillport,
   standup), and `just template-update` picks the variant's files by each
   instance's `.variant`. Removing them would cut those instances off.
3. **Handoffs stay the default even when every agent is Claude.** The
   claude-plus-agents docs now say so: the implementer and reviewer are usually
   a fresh Claude session or subagent, and another tool is the option, not the
   premise. No handoff-free path is added.
4. **New shared content goes to claude-plus-agents first.** A fix that applies to
   both variants is still mirrored while claude-only has live instances. A new
   feature need not be ported to claude-only.

## Consequences

- An instance on claude-only keeps receiving fixes through `template-update`.
  Moving one to claude-plus-agents is a manual migration (README estimates about
  an hour). There is no tool for it, and none is planned until an instance
  actually needs it.
- A small project pays for two handoffs per spec. If that overhead proves too
  high on a real small project, revisit this with that project's numbers. Do
  not reopen it from expectation.
- When no instance anyone works in is on claude-only, delete
  `variants/claude-only/`, the parity checks for it, and `test.sh`'s claude-only
  path, in one change.

## Not decided here

- Whether `init` should stop offering claude-only interactively.
- A `just migrate-variant` command.
