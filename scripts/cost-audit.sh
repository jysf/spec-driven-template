#!/usr/bin/env bash
# scripts/cost-audit.sh — the mechanical backstop for the Cost Tracking
# Discipline (AGENTS.md §4). Fails if any SHIPPED spec is missing real
# build/verify cost data (a positive `tokens_total` on those cycles).
#
# Why this exists: documentation alone tells agents to record cost, and
# documentation alone is skippable — cost tracking silently goes empty
# (all-null numerics) the moment a prompt says "leave it null". A check
# makes it stick. Same pattern as wiring a license policy into CI: a
# discipline made mechanical with a `just` check + a CI job.
#
# Scope: only build/verify cycles are required (those run as metered
# subagents whose token count is in the Agent result). design/ship are
# orchestrator main-loop cycles and may legitimately be null.
#
# Grandfathered pre-process specs are skipped — see
# COST_AUDIT_GRANDFATHERED in scripts/_lib.sh (empty in a fresh template
# instance; populate it only if you adopt the gate after shipping specs
# without it).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_initialized
project=$(get_active_project)
project_dir="${REPO_ROOT}/projects/${project}"

offenders=0
while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in *-timeline.md) continue ;; esac
    name=$(basename "$f" .md)
    # "shipped" = archived under done/, or front-matter cycle == ship.
    shipped=0
    case "$f" in
        */specs/done/*) shipped=1 ;;
        *) if [ "$(get_spec_cycle "$f")" = "ship" ]; then shipped=1; fi ;;
    esac
    [ "$shipped" = "1" ] || continue
    if is_grandfathered_cost "$name"; then continue; fi
    missing=$(spec_missing_cost_cycles "$f")
    if [ -n "$missing" ]; then
        printf "  %-58s missing cost on: %s\n" "$name" "$missing"
        offenders=$((offenders + 1))
    fi
done < <(find_all_specs "$project_dir")

if [ "$offenders" -gt 0 ]; then
    echo ""
    die "cost-audit: ${offenders} shipped spec(s) missing build/verify cost. Record tokens_total per AGENTS.md §4 / docs/cost-tracking.md."
fi
success "cost-audit: all shipped specs have build/verify cost recorded."
