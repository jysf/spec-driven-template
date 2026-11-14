---
source: "crustyimg (PROJ-011 + PROJ-017 running at once)"
captured_at: 2026-11-13
captured_by: claude
status: open                # open | addressed | deferred
---

# The tooling assumes one active project, but projects overlap in practice

## The issue

`scripts/_lib.sh` `get_active_project()` returns a single project. Among several
briefs marked `status: active`, the lowest-numbered wins in the template
(crustyimg's fork picks the highest-numbered). Every default-scoped command
(`just status`, `backlog`, `roadmap`, `cost-audit`) then shows only that one.

In crustyimg, PROJ-017 shipped a whole stage (STAGE-058, 8 specs) and has a
second stage active, while PROJ-011 still has two active stages. The
maintainer's ship order put PROJ-011 first, but PROJ-017's work started before
PROJ-011 closed. Marking PROJ-017 `active` would hide PROJ-011 from every
default view. Leaving it `proposed` makes the label false: a "proposed" project
with shipped work. Neither status is right, and the tooling forces the choice.

A side effect: because PROJ-017 stayed `proposed`, its stages never showed in
`just status`/`backlog`/`roadmap`, so every PROJ-017 prompt had to tell the
session "this stage is invisible to the tooling; that is expected".

## Context

Stage-level tooling already handles this: several stages can be active at once
(`get_active_stage_files`, added after PROJ-010 ran three stages in parallel).
The project level never got the same change.

## Suggested fix

- `get_active_project()` → `get_active_projects()`, returning every active
  project; keep the single-project function for callers that need one, and
  warn when more than one is active instead of silently choosing.
- `status`, `backlog` and `roadmap` loop over all active projects.
- `ACTIVE_PROJECT=` still overrides.
- Document in AGENTS that overlapping projects are allowed, and that a project
  goes `active` when its first stage goes active, not when the previous project
  ships.

## Priority (their assessment)

Medium. Nothing breaks, but the status field goes false or work goes invisible
whenever projects overlap, which the ship order alone does not prevent.

## Resolution

Filled in when status changes from open.
