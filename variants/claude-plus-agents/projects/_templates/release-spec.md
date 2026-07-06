---
# A RELEASE SPEC is the spec for cutting a release — tagging, building the
# artifact, publishing it through each channel, and confirming it actually runs
# on a machine that didn't build it. See AGENTS.md "During ship" and
# docs/decisions/DEC-006.
#
# It uses the same task.* schema as a normal spec (so `just validate`,
# `just cost-audit`, and `just status` treat it as first-class), with
# `task.type: release`. The value it adds over a plain spec is the
# ## Release Pre-Flight checklist below: a generic, portable set of
# runtime/operational categories that every release hits, so each project
# stops re-earning the same gotchas one release at a time. This variant
# delegates the cut to an implementer via handoffs/HANDOFF-*.md.

task:
  id: SPEC-XXX
  type: release                    # epic | story | task | bug | chore | release
  cycle: design                    # frame | design | build | verify | ship
  blocked: false
  priority: high                   # critical | high | medium | low
  complexity: M                    # a release is rarely trivial; M is the floor

project:
  id: PROJ-XXX
  stage: STAGE-XXX
repo:
  id: __REPO_ID__

handoff:
  from_agent: __ARCHITECT_MODEL__  # from .repo-context tier_map.design (DEC-005)
  to_agent: null                   # filled when HANDOFF is created (any agent — see docs/porting.md)
  created_at: null

references:
  decisions: []                    # [DEC-NNN, DEC-MMM]
  constraints: []                  # [constraint-id-1, constraint-id-2]
  related_specs: []                # [SPEC-NNN]

value_link: null

# Metered cycles (build/verify) require a real tokens_total on a shipped
# release — same rule as any spec. See AGENTS.md §4 and docs/cost-tracking.md.
cost:
  sessions: []
  totals:
    tokens_total: 0
    estimated_usd: 0
    session_count: 0
---

# SPEC-XXX: <Short Title>

## Context

Why this release, and what it ships. Link the stage / specs whose work is going
out in this cut, and the version/tag you intend to publish.

## Release Scope

- **Version / tag:** the exact tag you will cut, in this app's scheme
  (`spec.version.scheme` in `.repo-context.yaml`; default `calver` →
  `vYYYY.MM.PATCH`). Run `just next-version` for the suggested next tag. This is
  the *app* version — NOT the top-level `VERSION` file (that's template
  provenance). See `docs/versioning.md`.
- **What's included:** the shipped specs / patches in this release
- **Delivery shapes:** which of {binary · package · service · library} this
  release produces — this decides which pre-flight categories below apply, and
  which version scheme fits (semver for a library/public API; calver otherwise).

## Release cut is two-phase

A release session **cannot finish in one pass** — the irreversible tag/publish is
gated by a human/coordinator. Structure it so the reversible work lands first:
- **Phase 1 — reversible prep (CI-gated PR):** CHANGELOG entry, version bump
  (`just next-version`), stage-backlog tick. Fully revertable — land it as a
  normal PR.
- **Phase 2 — irreversible cut (human/coordinator-gated):** create the tag and
  publish to each channel, only after Phase 1 merges. The spec ships
  **"prep-complete, cut-deferred."**

## Release Pre-Flight

**A behavioral checklist — each item asks "does the released thing actually work
on a real host," not "is the shape right."** The categories are generic and
portable (DEC-006); **fill in the tool-specific command for each under your
stack** (the template ships the slot, the instance fills the truth — same
principle as the toolchain brief).

Mark each item's verification **timing**, because most can only be checked *after*
the cut: **`[now]`** = verified this session, evidence attached; **`[cut]`** = can
only be verified at Phase 2 (a clean-host install, a published-channel check,
notarization propagation) → **deferred, verified by whoever runs the cut** — record
it honestly as deferred, don't tick it as done in-session. Mark categories that
don't apply to this release's delivery shape as `N/A` with one word why.

- [ ] **1. Version / tag integrity & build provenance** — exactly one release tag points
      at the release commit; the version baked into the artifact matches the tag;
      no stale or duplicate tag on the same commit. **And the shipped artifact
      reports its own build provenance** (version + commit SHA) that matches the
      release commit — `just build-info` is the stamp; it must be injected into
      the build (DEC-008, `docs/versioning.md`). A user should be able to trace
      exactly what they're running back to source.
      - Command / evidence: <REPLACE — e.g. `git tag --points-at HEAD` and
        `<app> --version` reports the `just build-info` ref>
- [ ] **2. Artifact trust on a clean host** — a freshly-downloaded artifact is
      trusted by a machine that didn't build it (code-signing / notarization /
      OS quarantine — Gatekeeper, SmartScreen). "Does a stranger's machine run
      it without a scary prompt or a block?"
      - Command / evidence: <REPLACE — download the release asset on a second
        machine and run it>
- [ ] **3. Distribution-channel trust** — a *new* user can install cleanly
      through each published channel (package-manager tap/registry trust gates,
      first-install auth). "Install it the way a stranger would, on a machine
      that never saw the source."
      - Command / evidence: <REPLACE — e.g. `brew install …` on a clean host>
- [ ] **4. Data isolation** — a dev / test / CI build can never read or migrate
      **production** data. Confirm the prod data path is unreachable from a
      non-prod binary.
      - Command / evidence: <REPLACE — run the built binary with the dev env and
        assert it cannot resolve the prod DSN>
- [ ] **5. Runtime smoke on a clean host** — the *shipped* artifact runs (not
      just builds) on a fresh install: it starts, answers, and its headline
      capability works end-to-end.
      - Command / evidence: <REPLACE — the one command that proves it works>
- [ ] **6. Rollback / uninstall** — there is a known, tested way to withdraw or
      downgrade the release. Exercise it at least once.
      - Command / evidence: <REPLACE — e.g. `brew uninstall …` / re-tag prior>

If a real release surfaces a category this list doesn't cover, record it in
`guidance/signals.yaml` (`type: process-debt`) so a close can grow the generic
categories (DEC-006 keeps them category-level, not command-level).

## Notes for the Implementer

Gotchas specific to *this* release — a channel that's slow to propagate, a
signing cert that expires, an env var the release runner needs. Keep short — the
full context graph lives in the handoff file.

---

## Reflection

*Appended during **ship**. Four questions, short answers.*

1. **What would I do differently next release?**
   — <answer>

2. **Does any template, constraint, or decision need updating?** (e.g. a new
   pre-flight category to add to this template)
   — <answer — if yes but not done this session, record it in
   `/guidance/signals.yaml`. See `docs/signals.md`.>

3. **Is there a follow-up spec I should write now before I forget?**
   — <answer>

4. **Where was the worst defect caught?** — one word from a fixed vocabulary so
   the defect-escape distribution is greppable across specs:
   `design` | `build` | `verify` | `ship` | `escaped` (reached prod/runtime) |
   `none` (clean first try).
   — <one word>
   *(A release-phase `escaped` defect means a pre-flight category above was
   missing or skipped — grow the checklist.)*
