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
VALID_COMPLEXITY=" S M L "

offenders=0
checked=0

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
done < <(find "${REPO_ROOT}/projects" -maxdepth 1 -type d -name 'PROJ-*' 2>/dev/null | sort)

if [ "$offenders" -gt 0 ]; then
    echo ""
    die "validate: ${offenders} spec(s) with invalid/missing required front-matter (checked ${checked}). See DEC-001 §1 / docs/schema-reference.md."
fi
success "validate: ${checked} spec(s) have valid required front-matter."
