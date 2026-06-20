#!/usr/bin/env bash
# scripts/decisions-view.sh — the `just dash decisions` lens: browse repo
# decisions (each DEC-* with confidence, active/superseded status, scope, and
# title). Complements `just decisions-audit`, which *lints* rather than lists.
# --json emits ContextCore insight.* attribute names. Read-only.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_initialized
JSON_OUT=$(has_json_flag "$@")

decs=()
while IFS= read -r f; do [ -n "$f" ] && decs+=("$f"); done < <(find_all_decisions)

if [ "$JSON_OUT" = 1 ]; then
    items=()
    for f in "${decs[@]:-}"; do
        [ -n "$f" ] || continue
        id=$(get_dec_id "$f"); conf=$(get_dec_confidence "$f")
        sb=$(get_dec_superseded_by "$f"); title=$(get_dec_title "$f")
        scope_parts=()
        while IFS= read -r g; do [ -n "$g" ] && scope_parts+=("$(json_qs "$g")"); done < <(get_dec_affected_scope "$f")
        [ "${#scope_parts[@]}" -gt 0 ] && scope_arr=$(json_arr "${scope_parts[@]}") || scope_arr="[]"
        if [ -n "$sb" ]; then status=superseded; sbj=$(json_qs "$sb"); else status=active; sbj=null; fi
        case "$conf" in ''|null) confj=null ;; *) confj=$conf ;; esac
        items+=("$(json_obj \
            "insight.id" "$(json_qs "$id")" \
            "insight.confidence" "$confj" \
            status "$(json_qs "$status")" \
            superseded_by "$sbj" \
            title "$(json_qs "$title")" \
            affected_scope "$scope_arr")")
    done
    [ "${#items[@]}" -gt 0 ] && arr=$(json_arr "${items[@]}") || arr="[]"
    json_emit decisions "$(json_obj count "${#decs[@]}" decisions "$arr")"
    exit 0
fi

printf "${BOLD}Decisions (%d)${RESET}\n" "${#decs[@]}"
printf "${DIM}columns: flag · id · confidence · status · title  (⚠ = confidence < 0.7)${RESET}\n"
if [ "${#decs[@]}" -eq 0 ]; then printf "  ${DIM}(none)${RESET}\n"; exit 0; fi
for f in "${decs[@]}"; do
    id=$(get_dec_id "$f"); conf=$(get_dec_confidence "$f")
    sb=$(get_dec_superseded_by "$f"); title=$(get_dec_title "$f")
    [ -n "$conf" ] || conf="—"
    if [ -n "$sb" ]; then st="superseded→${sb}"; else st="active"; fi
    mark="  "
    case "$conf" in ''|—|null) : ;; *) awk -v x="$conf" 'BEGIN{exit !(x+0 < 0.7)}' && mark="⚠ " ;; esac
    printf "  %s%-9s  %-4s  %-20s  %s\n" "$mark" "$id" "$conf" "$st" "$title"
done
