#!/usr/bin/env bash
# scripts/validate.sh — the schema gate (DEC-001 §1).
#
# Checks that every spec's front-matter carries the required STRUCTURAL fields
# with valid values, so the front-matter stays a reliable contract for reports,
# `--json`, and any downstream consumer (MCP, exporter, UI). Exits non-zero on
# any violation — the CI gate contract (DEC-001 §2, exit 1).
#
# Scope (v1): specs. Cost recording on SHIPPED specs is a separate gate
# (`just cost-audit`); decision records are linted by `just decisions-audit`.
# This validator is the place to grow stage/brief checks over time.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_initialized

# fm_scalar FILE TOP SUB → first token of TOP.SUB (2-space-nested scalar),
# empty if absent. Tolerates trailing "# ..." comments (takes field $2).
fm_scalar() {
    awk -v top="$2" -v subk="$3" '
        /^---$/ { f = !f; next }
        !f { exit }
        $0 ~ ("^" top ":") { intop = 1; next }
        intop && /^[^[:space:]]/ { intop = 0 }
        intop && $0 ~ ("^[[:space:]]+" subk ":") { print $2; exit }
    ' "$1"
}

VALID_CYCLE=" frame design build verify ship "
VALID_PATCH_CYCLE=" patch verify ship "
VALID_COMPLEXITY=" S M L "
# `project.activity` is an OPEN, suggested set — not a hard enum. An
# unrecognized value is advisory (warn-only), never a gate failure, so
# people can extend the vocabulary (e.g. add `spike`). See DEC / AGENTS.
SUGGESTED_ACTIVITY=" requirements design build test blocked "

offenders=0
checked=0
activity_notes=""

while IFS= read -r pdir; do
    [ -n "$pdir" ] || continue
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        # Skip non-spec SPEC-*.md files that share the glob: cycle-prompt files
        # under specs/prompts/, and timeline artifacts.
        case "$f" in
            */prompts/*) continue ;;
            *-timeline.md) continue ;;
        esac
        name=$(basename "$f" .md)
        problems=""

        [ -n "$(fm_scalar "$f" task id)" ]      || problems="${problems} task.id"
        [ -n "$(fm_scalar "$f" task type)" ]    || problems="${problems} task.type"
        [ -n "$(fm_scalar "$f" project id)" ]   || problems="${problems} project.id"
        [ -n "$(fm_scalar "$f" project stage)" ]|| problems="${problems} project.stage"
        [ -n "$(fm_scalar "$f" repo id)" ]      || problems="${problems} repo.id"

        cyc=$(fm_scalar "$f" task cycle)
        case "$VALID_CYCLE" in *" $cyc "*) : ;; *) problems="${problems} task.cycle(='${cyc:-∅}')" ;; esac

        cx=$(fm_scalar "$f" task complexity)
        case "$VALID_COMPLEXITY" in *" $cx "*) : ;; *) problems="${problems} task.complexity(='${cx:-∅}')" ;; esac

        checked=$((checked + 1))
        if [ -n "$problems" ]; then
            printf "  %-52s invalid/missing:%s\n" "$name" "$problems"
            offenders=$((offenders + 1))
        fi
    done < <(find_all_specs "$pdir")

    # Patches (the patch lane, DEC-003): same task.* schema as specs, but the
    # cycle enum is patch/verify/ship and there is NO project.stage requirement
    # (a patch attaches to the project, not a stage).
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        case "$f" in
            */prompts/*) continue ;;
            *-timeline.md) continue ;;
        esac
        name=$(basename "$f" .md)
        problems=""

        [ -n "$(fm_scalar "$f" task id)" ]    || problems="${problems} task.id"
        [ -n "$(fm_scalar "$f" task type)" ]  || problems="${problems} task.type"
        [ -n "$(fm_scalar "$f" project id)" ] || problems="${problems} project.id"
        [ -n "$(fm_scalar "$f" repo id)" ]    || problems="${problems} repo.id"

        cyc=$(fm_scalar "$f" task cycle)
        case "$VALID_PATCH_CYCLE" in *" $cyc "*) : ;; *) problems="${problems} task.cycle(='${cyc:-∅}')" ;; esac

        cx=$(fm_scalar "$f" task complexity)
        case "$VALID_COMPLEXITY" in *" $cx "*) : ;; *) problems="${problems} task.complexity(='${cx:-∅}')" ;; esac

        checked=$((checked + 1))
        if [ -n "$problems" ]; then
            printf "  %-52s invalid/missing:%s\n" "$name" "$problems"
            offenders=$((offenders + 1))
        fi
    done < <(find_all_patches "$pdir")

    # Brief `project.activity` (optional, human-facing). OPEN set: an
    # unrecognized value is ADVISORY only — collected here, never counted
    # as an offender, so it can never fail the gate.
    act=$(get_project_activity "$pdir")
    if [ -n "$act" ]; then
        case "$SUGGESTED_ACTIVITY" in
            *" $act "*) : ;;
            *) activity_notes="${activity_notes}    $(basename "$pdir"): activity='${act}'"$'\n' ;;
        esac
    fi
done < <(find "${REPO_ROOT}/projects" -maxdepth 1 -type d -name 'PROJ-*' 2>/dev/null | sort)

# Advisory: an unrecognized `project.activity` (open set). Printed after
# the gate result — never changes the exit code.
if [ -n "$activity_notes" ]; then
    warn "validate: unrecognized project.activity (advisory — activity is an open set, not enforced; extend it freely):"
    printf '%s' "$activity_notes"
fi

if [ "$offenders" -gt 0 ]; then
    echo ""
    die "validate: ${offenders} artifact(s) with invalid/missing required front-matter (checked ${checked}). See DEC-001 §1 / docs/schema-reference.md."
fi
success "validate: ${checked} artifact(s) (specs + patches) have valid required front-matter."
