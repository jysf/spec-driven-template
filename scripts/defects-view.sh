#!/usr/bin/env bash
# scripts/defects-view.sh — the `just dash defects` lens: the defect-escape
# distribution (ship Reflection Q4 / a patch's Defect-catch-stage).
#
# Why this exists: every shipped spec already answers "where was the worst defect
# caught?" from a fixed vocabulary, and until now NOTHING read it. The retro that
# asked for the field said its value is "only visible in a cross-project view" —
# so the field shipped half-finished (the reserved-but-not-wired pattern, harvest
# signal #7). This is the reader.
#
# The number that matters is `escaped`: a defect that made it through design,
# build AND verify into the real world. Across the dogfood, EVERY escaped defect
# was operational/runtime rather than spec-logic — which is what the §12
# behavioral pre-flight exists to catch. A rising escaped count means the
# pre-flight isn't being run on the surfaces that need it.
#
# Scans ALL projects by default (the distribution is only meaningful in
# aggregate); pass --active or a PROJ-NNN to scope. Read-only.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_initialized
JSON_OUT=$(has_json_flag "$@")

SCOPE_DIRS=""
for a in "$@"; do
    case "$a" in
        --active) SCOPE_DIRS="${REPO_ROOT}/projects/$(get_active_project)" ;;
        PROJ-*)   SCOPE_DIRS=$(resolve_project_dir "$a") ;;
    esac
done
if [ -z "$SCOPE_DIRS" ]; then
    SCOPE_DIRS=$(find "${REPO_ROOT}/projects" -maxdepth 1 -type d -name 'PROJ-*' 2>/dev/null | sort)
fi

# Extract the answered defect-catch stage from one artifact.
#
# The vocabulary words also appear in the template's own prompt text, but ALWAYS
# wrapped in backticks (`design` | `build` | …). The answer is written bare. So:
# take the first BARE vocabulary word on an answer line, ignoring any line that
# contains a backtick. That keeps an unanswered template from counting as data.
defect_stage_of() {
    awk '
        # Spec form: the Q4 block, answer on a following "— <word>" line.
        /Where was the worst defect caught/ { inq = 1; n = 0; next }
        # Patch form: the answer follows the Defect-catch-stage bullet.
        /\*\*Defect-catch-stage:\*\*/ { inq = 1; n = 0 }
        inq && /`/ { next }                      # skip the vocabulary lines
        inq {
            # Bound the window: without this, an unanswered Q4 could swallow a
            # LATER question’s one-word answer (Q5 legitimately accepts "none").
            n++
            if (n > 10) exit
            line = $0
            # Strip everything up to the first lowercase letter. Deliberately NOT
            # a character class containing the em-dash: awk here is byte-oriented,
            # and "—" is three UTF-8 bytes, so [—-] shreds it mid-character and
            # leaves stray bytes glued to the answer.
            sub(/^[^a-z]*/, "", line)
            sub(/[[:space:]]*$/, "", line)
            if (line == "design" || line == "build" || line == "verify" ||
                line == "ship" || line == "escaped" || line == "none") {
                print line; exit
            }
            if (line ~ /^#/) exit
        }
    ' "$1"
}

c_design=0; c_build=0; c_verify=0; c_ship=0; c_escaped=0; c_none=0
answered=0; unanswered=0
esc_ids=(); esc_where=()

scan_one() {
    local f="$1" kind="$2"
    case "$f" in *-timeline.md|*/prompts/*) return 0 ;; esac
    local id stage
    id=$(basename "$f" .md)
    stage=$(defect_stage_of "$f")
    if [ -z "$stage" ]; then
        unanswered=$((unanswered + 1)); return 0
    fi
    answered=$((answered + 1))
    case "$stage" in
        design)  c_design=$((c_design + 1)) ;;
        build)   c_build=$((c_build + 1)) ;;
        verify)  c_verify=$((c_verify + 1)) ;;
        ship)    c_ship=$((c_ship + 1)) ;;
        none)    c_none=$((c_none + 1)) ;;
        escaped)
            c_escaped=$((c_escaped + 1))
            esc_ids+=("$id"); esc_where+=("$kind")
            ;;
    esac
}

while IFS= read -r pdir; do
    [ -n "$pdir" ] || continue
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        scan_one "$f" spec
    done < <(find_all_specs "$pdir")
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        scan_one "$f" patch
    done < <(find_all_patches "$pdir")
done <<EOF
${SCOPE_DIRS}
EOF

total=$((answered + unanswered))

if [ "$JSON_OUT" = 1 ]; then
    items=()
    i=0
    while [ "$i" -lt "${#esc_ids[@]}" ]; do
        items+=("$(json_obj artifact "$(json_qs "${esc_ids[$i]}")" kind "$(json_qs "${esc_where[$i]}")")")
        i=$((i + 1))
    done
    [ "${#items[@]}" -gt 0 ] && earr=$(json_arr "${items[@]}") || earr="[]"
    dist=$(json_obj design "$c_design" build "$c_build" verify "$c_verify" \
                    ship "$c_ship" escaped "$c_escaped" none "$c_none")
    json_emit defects "$(json_obj \
        total "$total" answered "$answered" unanswered "$unanswered" \
        distribution "$dist" escaped_artifacts "$earr")"
    exit 0
fi

printf "${BOLD}Defect-escape distribution (%d answered / %d artifacts)${RESET}\n" "$answered" "$total"
printf "${DIM}where the worst defect was caught — ship Reflection Q4 / a patch's Defect-catch-stage${RESET}\n"

if [ "$answered" -eq 0 ]; then
    printf "  ${DIM}(no artifact has answered Q4 yet — the distribution needs shipped specs)${RESET}\n"
    [ "$unanswered" -gt 0 ] && printf "  ${DIM}%d artifact(s) scanned with no answer recorded.${RESET}\n" "$unanswered"
    exit 0
fi

# A tiny inline bar, scaled to the largest bucket, so the shape reads at a glance.
max=$c_design
for n in $c_build $c_verify $c_ship $c_escaped $c_none; do
    [ "$n" -gt "$max" ] && max=$n
done
[ "$max" -gt 0 ] || max=1

row() {
    local label="$1" n="$2" hl="${3:-}"
    local width=$(( n * 24 / max ))
    local bar=""
    local i=0
    while [ "$i" -lt "$width" ]; do bar="${bar}█"; i=$((i + 1)); done
    local pct=$(( n * 100 / answered ))
    if [ -n "$hl" ] && [ "$n" -gt 0 ]; then
        printf "  ${BOLD}%-8s${RESET} %3d (%2d%%)  ${YELLOW}%s${RESET}\n" "$label" "$n" "$pct" "$bar"
    else
        printf "  %-8s %3d (%2d%%)  %s\n" "$label" "$n" "$pct" "$bar"
    fi
}

row design  "$c_design"
row build   "$c_build"
row verify  "$c_verify"
row ship    "$c_ship"
row escaped "$c_escaped" highlight
row none    "$c_none"

if [ "$c_escaped" -gt 0 ]; then
    echo ""
    printf "${YELLOW}⚠${RESET} %d defect(s) ESCAPED — through design, build and verify, into the real world:\n" "$c_escaped"
    i=0
    while [ "$i" -lt "${#esc_ids[@]}" ]; do
        printf "    %s ${DIM}(%s)${RESET}\n" "${esc_ids[$i]}" "${esc_where[$i]}"
        i=$((i + 1))
    done
    echo ""
    printf "${DIM}Across the dogfood every escaped defect was operational/runtime, not logic.${RESET}\n"
    printf "${DIM}Each one is a signal to strengthen the §12 behavioral pre-flight for that surface.${RESET}\n"
fi

if [ "$unanswered" -gt 0 ]; then
    echo ""
    printf "${DIM}%d artifact(s) have no Q4 answer — the distribution is only as good as its coverage.${RESET}\n" "$unanswered"
fi
