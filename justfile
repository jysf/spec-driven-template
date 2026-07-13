# Spec-driven repo template — command runner
#
# This justfile works BOTH before and after `just init`:
# - Before init: only `init` and `list-variants` are expected to work.
# - After init: all the daily commands work (status, new-spec, etc.)
#
# Run `just --list` to see everything.
#
# ┌─ CONVENTION ─────────────────────────────────────────────────────────────┐
# │ This justfile is TEMPLATE-MANAGED — it ships with the scaffold and gets   │
# │ updated when you pull template improvements. Do NOT add your project's    │
# │ build/dev/test/deploy recipes here; put them in `app.just` (imported      │
# │ below). Keeping them separate means a template update never conflicts     │
# │ with your app commands. See AGENTS.md §6.                                 │
# └──────────────────────────────────────────────────────────────────────────┘

# Project-owned recipes (build, dev, test, deploy, …). Optional (`?`) so a
# fresh clone still works before it exists; recipes here that share a name with
# a template recipe are overridden by this justfile (template recipes win).
import? 'app.just'

# Show all commands
default:
    @just --list

# ----------------------------------------------------------------------------
# ONE-TIME SETUP
# ----------------------------------------------------------------------------

# Initialize the repo: pick a variant and scaffold files to the root.
init:
    @echo "Spec-driven repo template — init"
    @echo ""
    @if [ -f AGENTS.md ]; then \
        echo "⚠  Already initialized (AGENTS.md exists at repo root)."; \
        echo "   Init is one-shot: it consumes variants/ when it runs."; \
        echo "   To start over, restore the repo from git or re-clone."; \
        exit 1; \
    fi
    @if [ ! -d variants ]; then \
        echo "⚠  variants/ directory is missing."; \
        echo "   This repo was already initialized (or the template was"; \
        echo "   modified). Restore from git or re-clone to re-init."; \
        exit 1; \
    fi
    @echo "Pick a variant:"
    @echo "  1) claude-only         (Claude plays every role; simpler)"
    @echo "  2) claude-plus-agents  (Claude architects, separate agent implements)"
    @echo ""
    @printf "Enter 1 or 2: "
    @read variant_choice && \
    if [ "$variant_choice" = "1" ]; then \
        VARIANT="claude-only"; \
    elif [ "$variant_choice" = "2" ]; then \
        VARIANT="claude-plus-agents"; \
    else \
        echo "Invalid choice: $variant_choice"; exit 1; \
    fi && \
    echo "" && \
    echo "Scaffolding $VARIANT to repo root..." && \
    cp -r "variants/$VARIANT/." . && \
    rm -rf variants/ && \
    echo "$VARIANT" > .variant && \
    echo "" && \
    echo "✓ Done. Your variant: $VARIANT" && \
    echo "" && \
    echo "Next steps:" && \
    echo "  1. Open GETTING_STARTED.md" && \
    echo "  2. Work through the PROJECT FRAME prompt in FIRST_SESSION_PROMPTS.md" && \
    echo "  3. Commit the scaffolded repo:" && \
    echo "       git add . && git commit -m 'chore: initialize spec-driven scaffold'"

# List the available variants (useful before init)
list-variants:
    @echo "Available variants:"
    @echo "  claude-only         — Claude plays every role; no handoff documents"
    @echo "  claude-plus-agents  — Claude architects, separate agent implements; adds /handoffs/"
    @echo ""
    @echo "Run 'just init' to pick one."

# ----------------------------------------------------------------------------
# DAILY COMMANDS (work after `just init`)
# ----------------------------------------------------------------------------

# Print repo state: active project, stage, specs by cycle, stale items.
# Pass --json for machine-readable output (DEC-001 §2).
status *ARGS:
    @./scripts/status.sh {{ARGS}}

# Scaffold a new spec. Usage: just new-spec "short title" STAGE-NNN [PROJ-NNN]
new-spec TITLE STAGE_ID PROJECT_ID="":
    @./scripts/new-spec.sh "{{TITLE}}" "{{STAGE_ID}}" "{{PROJECT_ID}}"

# Scaffold a release spec (DEC-006): a release cut with the generic runtime
# pre-flight checklist. Same as `new-spec --release`.
# Usage: just new-release-spec "short title" STAGE-NNN [PROJ-NNN]
new-release-spec TITLE STAGE_ID PROJECT_ID="":
    @./scripts/new-spec.sh "{{TITLE}}" "{{STAGE_ID}}" "{{PROJECT_ID}}" --release

# Scaffold a new stage. Usage: just new-stage "short title" [PROJ-NNN]
new-stage TITLE PROJECT_ID="":
    @./scripts/new-stage.sh "{{TITLE}}" "{{PROJECT_ID}}"

# Advance a spec's cycle. Usage: just advance-cycle SPEC-NNN verify
advance-cycle SPEC_ID NEW_CYCLE:
    @./scripts/advance-cycle.sh "{{SPEC_ID}}" "{{NEW_CYCLE}}"

# Archive a shipped spec: move to done/ and update stage backlog.
# Usage: just archive-spec SPEC-NNN
archive-spec SPEC_ID:
    @./scripts/archive-spec.sh "{{SPEC_ID}}"

# Scaffold a patch (the lightweight fix lane, DEC-003): a bounded fix to
# shipped behavior, patch -> verify -> ship. Usage: just new-patch "title" [PROJ-NNN]
new-patch TITLE PROJECT_ID="":
    @./scripts/new-patch.sh "{{TITLE}}" "{{PROJECT_ID}}"

# Archive a shipped patch: move to patches/done/ (no stage bookkeeping).
# Usage: just archive-patch PATCH-NNN
archive-patch PATCH_ID:
    @./scripts/archive-patch.sh "{{PATCH_ID}}"

#   just report daily [--json]         → curated daily report (reports/daily/YYYY-MM-DD.md)
#   just report weekly [DATE] [--json] → weekly report for the ISO week (reports/weekly/YYYY-WNN.md)
#   just report status                 → uncurated status snapshot (reports/daily/YYYY-MM-DD-status.md)
# `--json` emits a lean quantitative envelope to stdout (skips the prose file).
# `report-daily` / `report-weekly` remain permanent aliases (defined below).
# One report namespace (DEC-001 §3, Phase 3): daily | weekly [DATE] | status.
report SUB="" *REST:
    @case "{{SUB}}" in \
        daily)  ./scripts/report_daily.sh {{REST}} ;; \
        weekly) ./scripts/report_weekly.sh {{REST}} ;; \
        status) mkdir -p reports/daily; \
            D="$(date +%Y-%m-%d)"; \
            { echo "# Daily status - $D"; echo; ./scripts/status.sh; } > "reports/daily/$D-status.md"; \
            echo "✓ Wrote reports/daily/$D-status.md" ;; \
        *) echo "Usage: just report {daily [--json] | weekly [DATE] [--json] | status}" >&2; exit 2 ;; \
    esac

# Print the Weekly Review prompt with recent activity pre-loaded (DEC-001 §3).
review:
    @./scripts/weekly-review.sh

# Print the whole-repo Lifetime Data Report: all projects/stages/specs/decisions/releases, no LLM needed
lifetime-data:
    @./scripts/lifetime-report.sh data

# Print the Lifetime Report prompt: same history wrapped in a synthesis ask for an LLM to narrate
lifetime-report:
    @./scripts/lifetime-report.sh prompt

# Save the Lifetime Data Report to reports/lifetime/YYYY-MM-DD-HHMMSS.md
# (timestamped to the second, so repeated runs never overwrite).
lifetime-save:
    @mkdir -p reports/lifetime
    @TS="$(date +%Y-%m-%d-%H%M%S)"; \
        ./scripts/lifetime-report.sh data > "reports/lifetime/$TS.md" \
        && echo "✓ Wrote reports/lifetime/$TS.md"

# --- Permanent aliases (DEC-001 §3): muscle-memory wins over tidiness. ---

# Alias for `just report daily`. Generate today's daily report (`--json` for the
# quantitative envelope on stdout).
report-daily *REST:
    @./scripts/report_daily.sh {{REST}}

# Alias for `just report weekly [DATE]`. Pass a YYYY-MM-DD to report on the ISO
# week containing that date (`--json` for the envelope on stdout).
report-weekly *REST:
    @./scripts/report_weekly.sh {{REST}}

# The project dashboard — one read view, many lenses (DEC-001 §4). With no
# argument it stitches a single overview (now + future + cost + flags). The
# lenses are the existing views, which keep working as their own commands:
#   just dash now=status · next=backlog · future=roadmap · ledger=specs-by-stage
# Want a new slice? Add a lens to scripts/dash.sh — not a new command.
dash *ARGS:
    @./scripts/dash.sh {{ARGS}}

# Spec-grained "what's next?" view: in-flight specs in the active
# stage, un-promoted bullets in the active stage's backlog, and
# counts in upcoming stages. Pass --all to widen scope.
backlog *FLAGS:
    @./scripts/backlog.sh {{FLAGS}}

# Stage-grained "where is this project going" view: one row per
# stage in the active project with status, date range, and (for
# active/upcoming) spec counts.
roadmap *ARGS:
    @./scripts/roadmap.sh {{ARGS}}

# Flat ledger of every spec grouped by stage, with ship date and
# complexity. Defaults to ALL projects (history); pass `--active` for
# the current project or a `PROJ-NNN` id for a specific one.
specs-by-stage *FLAGS:
    @./scripts/specs-by-stage.sh {{FLAGS}}

# Audit decisions: structural lint + scope-conflict warnings (zero
# deps; a native take on LineSpec-style provenance auditing). Lints
# front-matter and supersession links across all DEC-* files. Pass
# `--changed [BASE]` to flag which decisions govern your pending changes.
decisions-audit *FLAGS:
    @./scripts/decisions-audit.sh {{FLAGS}}

# Fail if any shipped spec is missing real build/verify cost data
# (AGENTS.md §4 / docs/cost-tracking.md). Same check the CI `cost-data`
# job runs; also surfaced in `just status` and `just report-weekly`.
cost-audit:
    @./scripts/cost-audit.sh

# Validate that every spec's front-matter carries the required structural
# fields with valid values (the schema contract; DEC-001 §1 /
# docs/schema-reference.md). Exits non-zero on any violation — gate-style,
# suitable for CI. Cost-on-shipped is enforced separately by `just cost-audit`.
validate:
    @./scripts/validate.sh

# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------

# Print the active project and variant
info:
    @./scripts/info.sh

# Print the spec-driven template version (from the top-level VERSION file).
# An instance reports the template version it was scaffolded from. `--json`
# for machine-readable output.
template-version *ARGS:
    @./scripts/template-version.sh {{ARGS}}

# Suggest this APP's next release version per spec.version.scheme (DEC-007).
# Default calver → vYYYY.MM.PATCH. Distinct from `template-version` (which
# reports the TEMPLATE this repo came from). `--json` for machine-readable.
next-version *ARGS:
    @./scripts/next-version.sh {{ARGS}}

# The build provenance stamp (DEC-008): a string that traces a build back to its
# exact source commit (git-describe + SHA + dirty flag). Inject it into your
# artifact at build time so users know exactly what they're running — see
# docs/versioning.md "Build provenance". `--json` for machine-readable.
build-info *ARGS:
    @./scripts/build-info.sh {{ARGS}}

# Scaffolds a throwaway repo in a temp dir and runs the template's full suite
# (init -> cycle -> reports -> audits). Maintainers only: works from the
# pre-init template root; after `just init` it fails early by design.
# Maintainer self-test of the template itself (the app keeps `just test`).
template-selftest:
    @./scripts/test.sh
