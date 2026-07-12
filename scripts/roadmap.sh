#!/usr/bin/env bash
# scripts/roadmap.sh — stage-grained "where is this project going" view.
#
# One row per stage in the active project:
#   - Stage ID + title
#   - Status: shipped / active / upcoming (proposed/on_hold both render
#     as "upcoming" — the user-facing distinction we care about is
#     "done", "happening now", or "later")
#   - Date range:
#       shipped → created_at → shipped_at
#       active  → created_at → ?
#       upcoming → target: target_complete (or "—" if unset)
#   - Spec counts (in-flight / backlog) for active and upcoming stages
#
# Read-only. No writes.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

require_initialized

ACTIVE_PROJECT=$(get_active_project)
ACTIVE_DIR="${REPO_ROOT}/projects/${ACTIVE_PROJECT}"
STAGES_DIR="${ACTIVE_DIR}/stages"
SPECS_DIR="${ACTIVE_DIR}/specs"

# Count in-flight specs (cycle ≠ ship/archived) for a given stage ID.
count_in_flight_for_stage() {
    local stage_id="$1"
    local n=0 f c sid
    [ -d "$SPECS_DIR" ] || { echo 0; return; }
    for f in "${SPECS_DIR}"/SPEC-*.md; do
        [ -f "$f" ] || continue
        sid=$(awk '
            /^---$/ { fm = !fm; next }
            !fm { exit }
            /^project:/ { in_p = 1; next }
            in_p && /^[a-zA-Z_]/ { in_p = 0 }
            in_p && /^[[:space:]]+stage:/ { print $2; exit }
        ' "$f")
        if [ "$sid" = "$stage_id" ]; then
            c=$(get_spec_cycle "$f")
            case "$c" in
                frame|design|build|verify|ship) n=$((n + 1)) ;;
            esac
        fi
    done
    echo "$n"
}

# Count un-promoted "(not yet written)" bullets in a stage file.
count_backlog_bullets() {
    local f="$1"
    awk '
        /^## Spec Backlog/ { in_b = 1; next }
        in_b && /^## / { in_b = 0 }
        in_b && /\(not yet written\)/ { count++ }
        END { print count+0 }
    ' "$f"
}

# Emit the planned-but-unframed rows from the brief's ## Stage Plan:
# those with no matching STAGE-*.md file yet. Output is one
# `STAGEID|CHECKED|TITLE` row per planned stage (STAGEID may be `-`
# for a "(not yet defined)" row). A row whose STAGE-NNN already has a
# stage file is dropped — the file-driven loop already renders it.
collect_planned_rows() {
    local pid pchecked ptitle f found
    while IFS='|' read -r pid pchecked ptitle; do
        [ -n "$pid" ] || [ -n "$ptitle" ] || continue   # skip blank line
        if [ "$pid" != "-" ]; then
            found=0
            for f in "${STAGES_DIR}"/${pid}*.md; do
                [ -f "$f" ] && { found=1; break; }
            done
            [ "$found" = 1 ] && continue
        fi
        printf '%s|%s|%s\n' "$pid" "$pchecked" "$ptitle"
    done <<EOF
$(parse_stage_plan "$ACTIVE_DIR")
EOF
}

# --- JSON output (DEC-001 §2) ------------------------------------------------
if [ "$(has_json_flag "$@")" = 1 ]; then
    active_stage_file=$(get_active_stage_file "$ACTIVE_DIR" || true)
    active_stage_id=""
    [ -n "$active_stage_file" ] && active_stage_id=$(basename "$active_stage_file" .md | sed -E 's/^(STAGE-[0-9]+).*/\1/')
    stages_json=()
    if [ -d "$STAGES_DIR" ]; then
        for s in "${STAGES_DIR}"/STAGE-*.md; do
            [ -f "$s" ] || continue
            sid=$(basename "$s" .md | sed -E 's/^(STAGE-[0-9]+).*/\1/')
            status=$(get_stage_status "$s"); [ -n "$status" ] || status="?"
            case "$status" in
                shipped)   bucket=shipped ;;
                cancelled) bucket=cancelled ;;
                active)    if [ "$sid" = "$active_stage_id" ]; then bucket=active; else bucket=upcoming; fi ;;
                *)         bucket=upcoming ;;
            esac
            ca=$(get_stage_created_at "$s"); sa=$(get_stage_shipped_at "$s"); tg=$(get_stage_target "$s")
            inf=$(count_in_flight_for_stage "$sid"); bk=$(count_backlog_bullets "$s")
            stages_json+=("$(json_obj \
                "project.stage" "$(json_qs "$sid")" \
                "stage.status" "$(json_qs "$status")" \
                bucket "$(json_qs "$bucket")" \
                created_at "$([ -n "$ca" ] && json_qs "$ca" || printf null)" \
                shipped_at "$([ -n "$sa" ] && json_qs "$sa" || printf null)" \
                target_complete "$([ -n "$tg" ] && json_qs "$tg" || printf null)" \
                in_flight "$inf" \
                backlog "$bk")")
        done
    fi
    [ "${#stages_json[@]}" -gt 0 ] && stages_arr=$(json_arr "${stages_json[@]}") || stages_arr="[]"

    # Planned-but-unframed stages from the brief's ## Stage Plan.
    planned_json=()
    while IFS='|' read -r pid pchecked ptitle; do
        [ -n "$pid" ] || [ -n "$ptitle" ] || continue
        planned_json+=("$(json_obj \
            "project.stage" "$([ "$pid" != "-" ] && json_qs "$pid" || printf null)" \
            bucket "$(json_qs planned)" \
            title "$(json_qs "$ptitle")" \
            checked "$([ "$pchecked" = x ] && printf true || printf false)")")
    done <<EOF
$(collect_planned_rows)
EOF
    [ "${#planned_json[@]}" -gt 0 ] && planned_arr=$(json_arr "${planned_json[@]}") || planned_arr="[]"

    data=$(json_obj \
        active_project "$(json_qs "$ACTIVE_PROJECT")" \
        active_stage "$([ -n "$active_stage_id" ] && json_qs "$active_stage_id" || printf null)" \
        stages "$stages_arr" \
        planned "$planned_arr")
    json_emit roadmap "$data"
    exit 0
fi

echo "${BOLD}Roadmap for ${ACTIVE_PROJECT}${RESET}"

# Determine the "active stage" once so we can highlight it. Safe when
# there's no stages/ directory yet (returns empty).
ACTIVE_STAGE_FILE=$(get_active_stage_file "$ACTIVE_DIR" || true)
ACTIVE_STAGE_ID=""
if [ -n "$ACTIVE_STAGE_FILE" ]; then
    ACTIVE_STAGE_ID=$(basename "$ACTIVE_STAGE_FILE" .md | sed -E 's/^(STAGE-[0-9]+).*/\1/')
fi

any_stage=0
if [ -d "$STAGES_DIR" ]; then
for s in "${STAGES_DIR}"/STAGE-*.md; do
    [ -f "$s" ] || continue
    any_stage=1
    sname=$(basename "$s" .md)
    sid=$(echo "$sname" | sed -E 's/^(STAGE-[0-9]+).*/\1/')
    status=$(get_stage_status "$s")

    # User-facing status bucket. Multiple "active" stages are possible
    # in the data; only the first one (per get_active_stage_file) is
    # tagged "active" here. Others fall into "upcoming" so the roadmap
    # renders one happening-now row at a time.
    bucket=""
    case "$status" in
        shipped)   bucket="shipped" ;;
        cancelled) bucket="cancelled" ;;
        active)
            if [ "$sid" = "$ACTIVE_STAGE_ID" ]; then bucket="active"
            else bucket="upcoming"; fi
            ;;
        *)         bucket="upcoming" ;;
    esac

    # Date column.
    date_col=""
    case "$bucket" in
        shipped)
            sa=$(get_stage_shipped_at "$s")
            ca=$(get_stage_created_at "$s")
            date_col="${ca:-?} → ${sa:-?}"
            ;;
        cancelled)
            ca=$(get_stage_created_at "$s")
            date_col="${ca:-?} → cancelled"
            ;;
        active)
            ca=$(get_stage_created_at "$s")
            date_col="${ca:-?} → ?"
            ;;
        upcoming)
            t=$(get_stage_target "$s")
            if [ -n "$t" ]; then date_col="target: $t"
            else date_col="target: —"; fi
            ;;
    esac

    # Spec counts column (only for active and upcoming).
    counts_col=""
    if [ "$bucket" = "active" ] || [ "$bucket" = "upcoming" ]; then
        in_flight=$(count_in_flight_for_stage "$sid")
        backlog=$(count_backlog_bullets "$s")
        counts_col="(${in_flight} in flight, ${backlog} backlog)"
    fi

    # Render. Bold the active row to make "you are here" obvious.
    if [ "$bucket" = "active" ]; then
        printf "  ${BOLD}%-36s %-10s %-22s${RESET} %s\n" \
            "$sname" "$bucket" "$date_col" "$counts_col"
    else
        printf "  %-36s %-10s %-22s %s\n" \
            "$sname" "$bucket" "$date_col" "$counts_col"
    fi
done
fi  # end: [ -d "$STAGES_DIR" ]

# Planned-but-unframed stages from the brief's ## Stage Plan. Rendered
# after the file-driven rows so the roadmap shows the whole forward
# arc, not just the stages that have been framed into files.
planned_rows=$(collect_planned_rows)
if [ -n "$planned_rows" ]; then
    while IFS='|' read -r pid pchecked ptitle; do
        [ -n "$pid" ] || [ -n "$ptitle" ] || continue
        pname=$([ "$pid" != "-" ] && echo "$pid" || echo "(unframed)")
        printf "  ${DIM}%-36s %-10s %s${RESET}\n" "$pname" "planned" "$ptitle"
    done <<EOF
$planned_rows
EOF
fi

if [ "$any_stage" = "0" ] && [ -z "$planned_rows" ]; then
    if [ -d "$STAGES_DIR" ]; then
        echo "  ${DIM}(no stages yet)${RESET}"
    else
        echo "  ${DIM}(no stages/ directory yet)${RESET}"
    fi
fi
