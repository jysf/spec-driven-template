#!/usr/bin/env bash
# scripts/status.sh — print repo state report.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

require_initialized

VARIANT=$(get_variant)
ACTIVE_PROJECT=$(get_active_project)
ACTIVE_PROJECT_DIR="${REPO_ROOT}/projects/${ACTIVE_PROJECT}"

# --- JSON output (DEC-001 §2) ------------------------------------------------
if [ "$(has_json_flag "$@")" = 1 ]; then
    specs_json=(); missing_specs=()
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        case "$f" in *-timeline.md|*/prompts/*) continue ;; esac
        sid=$(basename "$f" | sed -E 's/^(SPEC-[0-9]+).*/\1/')
        name=$(basename "$f" .md)
        cyc=$(get_spec_cycle "$f"); [ -n "$cyc" ] || cyc="?"
        u=$(sum_cost_usd_for_spec "$f"); t=$(sum_cost_tokens_for_spec "$f")
        case "$f" in
            */specs/done/*) shipped=true ;;
            *) if [ "$cyc" = ship ]; then shipped=true; else shipped=false; fi ;;
        esac
        mc_json="[]"
        if [ "$shipped" = true ] && ! is_grandfathered_cost "$name"; then
            m=$(spec_missing_cost_cycles "$f")
            if [ -n "$m" ]; then
                parts=(); for c in $m; do parts+=("$(json_qs "$c")"); done
                mc_json=$(json_arr "${parts[@]}")
                missing_specs+=("$(json_qs "$sid")")
            fi
        fi
        specs_json+=("$(json_obj \
            "task.id" "$(json_qs "$sid")" \
            "task.cycle" "$(json_qs "$cyc")" \
            shipped "$shipped" \
            "cost.tokens_total" "$t" \
            "cost.estimated_usd" "$u" \
            missing_cost "$mc_json")")
    done < <(find_all_specs "$ACTIVE_PROJECT_DIR")
    [ "${#specs_json[@]}" -gt 0 ] && specs_arr=$(json_arr "${specs_json[@]}") || specs_arr="[]"
    [ "${#missing_specs[@]}" -gt 0 ] && missing_arr=$(json_arr "${missing_specs[@]}") || missing_arr="[]"
    total_specs=$(find "${ACTIVE_PROJECT_DIR}/specs" -name "SPEC-*.md" 2>/dev/null | awk '!/-timeline\.md/ && !/\/prompts\//' | wc -l | tr -d ' ')
    shipped_specs=$(find "${ACTIVE_PROJECT_DIR}/specs/done" -name "SPEC-*.md" 2>/dev/null | awk '!/-timeline\.md/' | wc -l | tr -d ' ')
    total_decisions=$(find "${REPO_ROOT}/decisions" -name "DEC-*.md" 2>/dev/null | wc -l | tr -d ' ')
    summary=$(json_obj total_specs "${total_specs:-0}" shipped "${shipped_specs:-0}" decisions "${total_decisions:-0}")
    data=$(json_obj \
        variant "$(json_qs "$VARIANT")" \
        active_project "$(json_qs "$ACTIVE_PROJECT")" \
        specs "$specs_arr" \
        missing_cost_specs "$missing_arr" \
        summary "$summary")
    json_emit status "$data"
    exit 0
fi

echo "${BOLD}Repo status${RESET}"
echo ""
echo "  Variant:         ${VARIANT}"
echo "  Active project:  ${ACTIVE_PROJECT}"
echo ""

# --- All projects ---
echo "${BOLD}All projects${RESET}"
for p in "${REPO_ROOT}"/projects/PROJ-*; do
    [ -d "$p" ] || continue
    pname=$(basename "$p")
    brief="${p}/brief.md"
    status="unknown"
    if [ -f "$brief" ]; then
        # Grep for "status:" nested under "project:" in the front-matter
        status=$(awk '
            /^---$/ { f = !f; next }
            f && /^project:/ { inproj = 1; next }
            f && inproj && /^[a-zA-Z_]+:/ { inproj = 0 }
            f && inproj && /^[[:space:]]+status:/ { print $2; exit }
        ' "$brief" 2>/dev/null || echo "unknown")
    fi
    marker=" "
    if [ "$pname" = "$ACTIVE_PROJECT" ]; then marker="${GREEN}*${RESET}"; fi
    printf "  %s %-40s  status: %s\n" "$marker" "$pname" "$status"
done
echo ""

# --- Active project: stages ---
echo "${BOLD}Stages in ${ACTIVE_PROJECT}${RESET}"
stages_dir="${ACTIVE_PROJECT_DIR}/stages"
if [ -d "$stages_dir" ]; then
    for s in "${stages_dir}"/STAGE-*.md; do
        [ -f "$s" ] || continue
        sname=$(basename "$s" .md)
        pstatus=$(awk '/^---$/{f=!f; next} f && /^[[:space:]]+status:/{print $2; exit}' "$s" 2>/dev/null || echo "unknown")
        printf "  %-44s  status: %s\n" "$sname" "$pstatus"
    done
else
    echo "  ${DIM}(no stages dir yet)${RESET}"
fi
echo ""

# --- Active project: specs by cycle ---
echo "${BOLD}Specs in ${ACTIVE_PROJECT} by cycle${RESET}"
specs_dir="${ACTIVE_PROJECT_DIR}/specs"
if [ -d "$specs_dir" ]; then
    for cycle in frame design build verify ship; do
        count=0
        names=""
        for f in "${specs_dir}"/SPEC-*.md; do
            [ -f "$f" ] || continue
            spec_cycle=$(awk '/^---$/{f=!f; next} f && /^[[:space:]]+cycle:/{print $2; exit}' "$f" 2>/dev/null || echo "")
            if [ "$spec_cycle" = "$cycle" ]; then
                count=$((count + 1))
                names="${names}    - $(basename "$f" .md)\n"
            fi
        done
        # Also count done/ as ship
        if [ "$cycle" = "ship" ] && [ -d "${specs_dir}/done" ]; then
            for f in "${specs_dir}/done"/SPEC-*.md; do
                [ -f "$f" ] || continue
                count=$((count + 1))
                names="${names}    - $(basename "$f" .md) ${DIM}(archived)${RESET}\n"
            done
        fi
        printf "  ${BOLD}%-8s${RESET} (%d)\n" "$cycle" "$count"
        if [ -n "$names" ]; then
            printf "%b" "$names"
        fi
    done
else
    echo "  ${DIM}(no specs yet)${RESET}"
fi
echo ""

# --- Low-confidence decisions ---
echo "${BOLD}Low-confidence decisions (< 0.7)${RESET}"
decisions_dir="${REPO_ROOT}/decisions"
found_any=false
if [ -d "$decisions_dir" ]; then
    for d in "${decisions_dir}"/DEC-*.md; do
        [ -f "$d" ] || continue
        conf=$(awk '/^---$/{f=!f; next} f && /^[[:space:]]+confidence:/{print $2; exit}' "$d" 2>/dev/null || echo "")
        if [ -n "$conf" ]; then
            # Use awk for float comparison (portable)
            low=$(awk -v c="$conf" 'BEGIN { print (c + 0 < 0.7) ? "1" : "0" }')
            if [ "$low" = "1" ]; then
                printf "  %-42s  confidence: %s\n" "$(basename "$d" .md)" "$conf"
                found_any=true
            fi
        fi
    done
fi
if [ "$found_any" = "false" ]; then
    echo "  ${DIM}(none — or no decisions yet)${RESET}"
fi
echo ""

# --- Stale specs (no commits on their branch in 7 days, approximate) ---
echo "${BOLD}Possibly stale specs${RESET}"
echo "  ${DIM}(heuristic: specs in build/verify with file mtime > 7 days)${RESET}"
found_stale=false
if [ -d "$specs_dir" ]; then
    for f in "${specs_dir}"/SPEC-*.md; do
        [ -f "$f" ] || continue
        cycle=$(awk '/^---$/{fm=!fm; next} fm && /^[[:space:]]+cycle:/{print $2; exit}' "$f" 2>/dev/null || echo "")
        if [ "$cycle" = "build" ] || [ "$cycle" = "verify" ]; then
            # Age in days (portable across macOS and Linux).
            if [ "$(uname)" = "Darwin" ]; then
                age_days=$(( ( $(date +%s) - $(stat -f %m "$f") ) / 86400 ))
            else
                age_days=$(( ( $(date +%s) - $(stat -c %Y "$f") ) / 86400 ))
            fi
            if [ "$age_days" -gt 7 ]; then
                printf "  %-40s  cycle: %-8s  age: %d days\n" "$(basename "$f" .md)" "$cycle" "$age_days"
                found_stale=true
            fi
        fi
    done
fi
if [ "$found_stale" = "false" ]; then
    echo "  ${DIM}(none)${RESET}"
fi
echo ""

# --- Specs missing cost data (shipped, non-grandfathered) ---
echo "${BOLD}Specs missing cost data${RESET}"
echo "  ${DIM}(shipped specs whose build/verify cycles lack tokens_total — run just cost-audit)${RESET}"
found_missing_cost=false
for f in $(find_all_specs "$ACTIVE_PROJECT_DIR"); do
    case "$f" in *-timeline.md) continue ;; esac
    name=$(basename "$f" .md)
    shipped=0
    case "$f" in
        */specs/done/*) shipped=1 ;;
        *) if [ "$(get_spec_cycle "$f")" = "ship" ]; then shipped=1; fi ;;
    esac
    [ "$shipped" = "1" ] || continue
    if is_grandfathered_cost "$name"; then continue; fi
    missing=$(spec_missing_cost_cycles "$f")
    if [ -n "$missing" ]; then
        printf "  %-44s  missing: %s\n" "$name" "$missing"
        found_missing_cost=true
    fi
done
if [ "$found_missing_cost" = "false" ]; then
    echo "  ${DIM}(none)${RESET}"
fi
echo ""

# --- Summary counts ---
total_specs=$(find "${ACTIVE_PROJECT_DIR}/specs" -name "SPEC-*.md" 2>/dev/null | wc -l | tr -d ' ')
shipped_specs=$(find "${ACTIVE_PROJECT_DIR}/specs/done" -name "SPEC-*.md" 2>/dev/null | wc -l | tr -d ' ')
total_decisions=$(find "$decisions_dir" -name "DEC-*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "${BOLD}Summary${RESET}"
echo "  Total specs in ${ACTIVE_PROJECT}:     ${total_specs}"
echo "  Shipped (archived):                   ${shipped_specs}"
echo "  Total decisions (across all projects): ${total_decisions}"
