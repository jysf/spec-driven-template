#!/usr/bin/env bash
# scripts/context-view.sh — the `just dash context` lens: which KIND of context
# problem build/verify agents report (the CAFE(S) word in the build reflection).
#
# Why this exists: every build reflection already asks "what was unclear?" and
# "what should have been listed?", but the answers are prose, so nothing could
# count them. The 2026-11-19 harvest sorted 1,047 of them by hand-rubric and
# found the question misleads: asked what was UNCLEAR, agents most often
# reported something that was WRONG or STALE (fidelity), and a reader of the
# prose can't tell the two apart. So the reflection now ends with one word from
# a fixed vocabulary — clarity | actionability | fidelity | none — and this is
# the reader that ships with it (field + reader in one change).
#
# Where the word lives:
#   claude-only        the spec's "Build-phase reflection", Q4
#   claude-plus-agents the handoff's "## Handback" reflection, Q4
#
# Efficiency and security (the E and S of CAFE(S)) are deliberately NOT in the
# vocabulary: agents never report them (2 and 0 of 610 problem answers in the
# harvest). Noise is paid for in tokens, not noticed — measure it from cost.*.
#
# Scans ALL projects by default; pass --active or a PROJ-NNN to scope. Read-only.
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
        --json)   : ;;
        *)        die "Unknown argument: '$a' (use: --active | PROJ-NNN | --json)" ;;
    esac
done
if [ -z "$SCOPE_DIRS" ]; then
    SCOPE_DIRS=$(find "${REPO_ROOT}/projects" -maxdepth 1 -type d -name 'PROJ-*' 2>/dev/null | sort)
fi

# Extract the answered context word from one artifact, or nothing.
#
# Same rule as defects-view: the vocabulary also appears in the template's own
# prompt text, but always in backticks, while the answer is written bare. So
# take the first BARE vocabulary word after the question, skip any line holding
# a backtick, and stop at the next heading or numbered question — a spec's Ship
# reflection follows, and its Q5 legitimately accepts "none".
context_word_of() {
    awk '
        /Which kind of context problem was the worst one/ { inq = 1; n = 0; next }
        !inq { next }
        /^#/ || /^---/ || /^[0-9]+\. \*\*/ { exit }
        /`/ { next }
        {
            n++
            if (n > 12) exit
            # Lowercase first: "Fidelity." is an answer, and the strip below
            # would otherwise eat its capital letter.
            line = tolower($0)
            # Strip up to the first lowercase letter (the "— " lead-in). Not a
            # character class with the em-dash: awk is byte-oriented here and
            # "—" is three UTF-8 bytes (see defects-view.sh).
            sub(/^[^a-z]*/, "", line)
            sub(/[[:space:].]*$/, "", line)
            if (line == "clarity" || line == "actionability" ||
                line == "fidelity" || line == "none") { print line; exit }
        }
    ' "$1"
}

c_clarity=0; c_action=0; c_fidelity=0; c_none=0
answered=0; unanswered=0
hit_ids=(); hit_kind=(); hit_word=()

scan_one() {
    local f="$1" kind="$2" id word
    case "$f" in *-timeline.md|*/prompts/*) return 0 ;; esac
    # Only artifacts whose template carries the question count as unanswered;
    # older artifacts that predate it are not missing data, just older.
    grep -q 'Which kind of context problem was the worst one' "$f" 2>/dev/null || return 0
    id=$(basename "$f" .md)
    word=$(context_word_of "$f")
    if [ -z "$word" ]; then
        unanswered=$((unanswered + 1)); return 0
    fi
    answered=$((answered + 1))
    case "$word" in
        clarity)       c_clarity=$((c_clarity + 1)) ;;
        actionability) c_action=$((c_action + 1)) ;;
        fidelity)      c_fidelity=$((c_fidelity + 1)) ;;
        none)          c_none=$((c_none + 1)) ;;
    esac
    if [ "$word" != none ]; then
        hit_ids+=("$id"); hit_kind+=("$kind"); hit_word+=("$word")
    fi
    return 0
}

while IFS= read -r pdir; do
    [ -n "$pdir" ] || continue
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        scan_one "$f" spec
    done < <(find_all_specs "$pdir")
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        scan_one "$f" handoff
    done < <(find "${pdir}/handoffs" -type f -name 'HANDOFF-*.md' 2>/dev/null | sort)
done <<EOF
${SCOPE_DIRS}
EOF

total=$((answered + unanswered))

if [ "$JSON_OUT" = 1 ]; then
    items=()
    i=0
    while [ "$i" -lt "${#hit_ids[@]}" ]; do
        items+=("$(json_obj artifact "$(json_qs "${hit_ids[$i]}")" kind "$(json_qs "${hit_kind[$i]}")" \
                            context "$(json_qs "${hit_word[$i]}")")")
        i=$((i + 1))
    done
    [ "${#items[@]}" -gt 0 ] && arr=$(json_arr "${items[@]}") || arr="[]"
    dist=$(json_obj clarity "$c_clarity" actionability "$c_action" fidelity "$c_fidelity" none "$c_none")
    json_emit context "$(json_obj \
        total "$total" answered "$answered" unanswered "$unanswered" \
        distribution "$dist" problem_artifacts "$arr")"
    exit 0
fi

printf "${BOLD}Context problems reported by build/verify (%d answered / %d artifacts)${RESET}\n" "$answered" "$total"
printf "${DIM}the worst kind, one word per build reflection (CAFE(S): clarity · actionability · fidelity)${RESET}\n"

if [ "$answered" -eq 0 ]; then
    printf "  ${DIM}(no reflection has answered the context question yet)${RESET}\n"
    [ "$unanswered" -gt 0 ] && printf "  ${DIM}%d artifact(s) carry the question with no answer recorded.${RESET}\n" "$unanswered"
    exit 0
fi

max=$c_clarity
for n in $c_action $c_fidelity $c_none; do
    [ "$n" -gt "$max" ] && max=$n
done
[ "$max" -gt 0 ] || max=1
row() {
    local label="$1" n="$2" hint="$3"
    local width=$(( n * 24 / max )) bar="" i=0
    while [ "$i" -lt "$width" ]; do bar="${bar}█"; i=$((i + 1)); done
    printf "  %-13s %3d (%2d%%)  %-24s ${DIM}%s${RESET}\n" "$label" "$n" $(( n * 100 / answered )) "$bar" "$hint"
}
row clarity       "$c_clarity"  "read more than one way"
row actionability "$c_action"   "needed, never said"
row fidelity      "$c_fidelity" "said, but wrong or stale"
row none          "$c_none"     "nothing slowed it down"

# Point at the remedy for whichever problem leads. Advisory only.
problems=$((c_clarity + c_action + c_fidelity))
if [ "$problems" -gt 0 ]; then
    echo ""
    if [ "$c_fidelity" -ge "$c_action" ] && [ "$c_fidelity" -ge "$c_clarity" ]; then
        printf "${DIM}Fidelity leads: design is asserting things about the code it did not check.\n"
        printf "Probe before you write it into the spec (AGENTS.md: verify claims against data).${RESET}\n"
    elif [ "$c_action" -ge "$c_clarity" ]; then
        printf "${DIM}Actionability leads: specs and handoffs leave out what the agent needed —\n"
        printf "a default, a test seam, or a rule from a DEC not repeated where it applies.${RESET}\n"
    else
        printf "${DIM}Clarity leads: terms or criteria in specs admit more than one reading.${RESET}\n"
    fi
fi

if [ "$unanswered" -gt 0 ]; then
    echo ""
    printf "${DIM}%d artifact(s) carry the question but no answer — the distribution is only as good as its coverage.${RESET}\n" "$unanswered"
fi
