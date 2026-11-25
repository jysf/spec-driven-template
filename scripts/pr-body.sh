#!/usr/bin/env bash
# scripts/pr-body.sh — print a spec PR's description, filled from front-matter.
#
# AGENTS.md §13 lists the ids a PR description must carry (project, stage,
# spec, handoff, decisions, constraints, new DECs). Nothing read that list, so
# agents typed it by hand: across 7 instances most spec PRs carried the ids,
# but "constraints checked" appeared in as few as 4 of 60 (irradiance). Every
# id here is derivable from the spec and the diff, so this derives it.
#
# A .github PR template would not have helped: agents open PRs with
# `gh pr create --body …`, and an explicit --body never loads the template.
#
# The PR is one cycle of one spec (frame/design/build/verify/ship each get
# their own PR in practice). Pass the cycle: by the time a build agent opens
# its PR it has already run `advance-cycle … verify`, so the spec's own
# `task.cycle` names the NEXT cycle, not this PR's.
#
# Constraints are listed when one of their `paths:` globs matches a file in
# the diff, as unticked boxes: this lists what to check, it does not check.
#
# Usage:
#   just pr-body SPEC-NNN [CYCLE] [--base REF] [--json]
#   gh pr create --title "build(SPEC-007): …" --body "$(just pr-body SPEC-007 build)"
#
# Exit: 0 ok · 1 spec not found · 2 usage error.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
require_initialized

JSON_OUT=$(has_json_flag "$@")
SPEC_ID=""; CYCLE=""; BASE=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --json) ;;
        --base) [ "$#" -ge 2 ] || usage_error "--base needs a ref"; BASE="$2"; shift ;;
        --base=*) BASE="${1#--base=}" ;;
        -*) usage_error "unknown flag '$1'. just pr-body SPEC-NNN [CYCLE] [--base REF] [--json]" ;;
        *)
            if [ -z "$SPEC_ID" ]; then SPEC_ID="$1"
            elif [ -z "$CYCLE" ]; then CYCLE="$1"
            else usage_error "too many arguments. just pr-body SPEC-NNN [CYCLE] [--base REF] [--json]"
            fi ;;
    esac
    shift
done

[ -n "$SPEC_ID" ] || usage_error "just pr-body SPEC-NNN [CYCLE] [--base REF] [--json]"
case "$SPEC_ID" in
    SPEC-[0-9]*) ;;
    *) usage_error "expected a SPEC-NNN id, got '${SPEC_ID}'." ;;
esac
case "$CYCLE" in
    ""|frame|design|build|verify|ship) ;;
    *) usage_error "cycle must be frame|design|build|verify|ship, got '${CYCLE}'." ;;
esac

# Notes go to stderr so `--body "$(just pr-body …)"` captures only the body.
note() { echo "pr-body: $*" >&2; }

# The spec, archived or not: a ship PR is the one that moves it into done/,
# so find_spec (which skips done/) would miss it exactly when it's needed.
SPEC_FILE=$(find "${REPO_ROOT}/projects" -type f -name "${SPEC_ID}-*.md" \
    -not -name '*-timeline.md' -not -path '*/prompts/*' -not -path '*/_templates/*' \
    2>/dev/null | sort | sed -n 1p || true)
[ -n "$SPEC_FILE" ] || die "No spec ${SPEC_ID} found under projects/."

# project.id — the sibling of project.stage (get_spec_stage) in the same block.
get_spec_project() {
    awk '
        /^---$/ { f = !f; next }
        !f { exit }
        /^project:/ { p = 1; next }
        p && /^[a-zA-Z_]/ { p = 0 }
        p && /^[[:space:]]+id:/ { print $2; exit }
    ' "$1"
}

TITLE=$(get_spec_title "$SPEC_FILE")
PROJECT=$(get_spec_project "$SPEC_FILE")
STAGE=$(get_spec_stage "$SPEC_FILE")
[ -n "$CYCLE" ] || CYCLE=$(get_spec_cycle "$SPEC_FILE")
case "$PROJECT" in PROJ-[0-9]*) ;; *) PROJECT="" ;; esac
case "$STAGE" in STAGE-[0-9]*) ;; *) STAGE="" ;; esac

DECS=()
while IFS= read -r d; do
    case "$d" in DEC-[0-9]*) DECS+=("$d") ;; esac
done < <(get_spec_referenced_decisions "$SPEC_FILE")

# Handoffs for this spec (claude-plus-agents; none in claude-only), with the
# cycle each delegates. Read with the shared block-scalar reader.
HO_IDS=(); HO_CYCLES=()
while IFS= read -r hf; do
    [ -n "$hf" ] || continue
    [ "$(_get_fm_block_scalar "$hf" task spec_id)" = "$SPEC_ID" ] || continue
    HO_IDS+=("$(basename "$hf" .md | grep -oE '^HANDOFF-[0-9]+' || true)")
    HO_CYCLES+=("$(get_handoff_field "$hf" cycle)")
done < <(find "${REPO_ROOT}/projects" -type f -name 'HANDOFF-*.md' \
            -not -path '*/_templates/*' -not -path '*/prompts/*' 2>/dev/null | sort)

# --- the diff --------------------------------------------------------------
# Same base resolution as `decisions-audit --changed`: explicit ref, else
# origin/HEAD, else main/master. Committed branch work plus anything still
# uncommitted, so it is right whether run before or after the last commit.
CHANGED=(); BASE_DESC=""
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    if [ -z "$BASE" ]; then
        BASE=$(git -C "$REPO_ROOT" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
        if [ -z "$BASE" ]; then
            for cand in main master; do
                if git -C "$REPO_ROOT" rev-parse --verify -q "$cand" >/dev/null 2>&1; then
                    BASE="$cand"; break
                fi
            done
        fi
    elif ! git -C "$REPO_ROOT" rev-parse --verify -q "$BASE" >/dev/null 2>&1; then
        usage_error "--base '${BASE}' is not a ref in this repo."
    fi
    if [ -n "$BASE" ]; then
        while IFS= read -r p; do
            [ -n "$p" ] && CHANGED+=("$p")
        done < <({
            git -C "$REPO_ROOT" diff --name-only "${BASE}...HEAD"
            git -C "$REPO_ROOT" diff --name-only HEAD
            git -C "$REPO_ROOT" ls-files --others --exclude-standard
        } 2>/dev/null | sort -u)
        BASE_DESC="${BASE}...HEAD"
    fi
fi
[ -n "$BASE_DESC" ] || note "no diff base found (not a git repo, or no main/master); pass --base REF. Constraints and new DECs are left empty."

# New DECs: DEC files in the diff that the base does not have.
NEW_DECS=()
dec_rel=$(decisions_dir); dec_rel="${dec_rel#"${REPO_ROOT}"/}"
for p in "${CHANGED[@]:-}"; do
    case "$p" in "${dec_rel}"/DEC-[0-9]*.md) ;; *) continue ;; esac
    [ -f "${REPO_ROOT}/${p}" ] || continue
    if ! git -C "$REPO_ROOT" cat-file -e "${BASE}:${p}" 2>/dev/null; then
        NEW_DECS+=("$(basename "$p" .md | grep -oE '^DEC-[0-9]+' || true)")
    fi
done

# Constraints whose paths match the diff.
C_IDS=(); C_SEVS=(); C_RULES=()
if [ "${#CHANGED[@]}" -gt 0 ]; then
    while IFS="$(printf '\t')" read -r cid csev cpaths _cby crule; do
        [ -n "$cid" ] || continue
        hit=0
        while IFS= read -r g; do
            re="^$(glob_to_regex "$g")$"
            for p in "${CHANGED[@]}"; do
                if [[ "$p" =~ $re ]]; then hit=1; break; fi
            done
            [ "$hit" = 1 ] && break
        done < <(constraint_path_globs "$cpaths")
        if [ "$hit" = 1 ]; then
            C_IDS+=("$cid"); C_SEVS+=("$csev"); C_RULES+=("$crule")
        fi
    done < <(emit_constraints_tsv)
fi

PR_TITLE="${CYCLE:-spec}(${SPEC_ID}): ${TITLE}"

# --- output ----------------------------------------------------------------
join_or_none() { if [ "$#" -gt 0 ] && [ -n "$1" ]; then local IFS=,; printf '%s' "$*" | sed 's/,/, /g'; else printf 'none'; fi; }

if [ "$JSON_OUT" = 1 ]; then
    qs_list() { local out=() x; for x in "$@"; do [ -n "$x" ] && out+=("$(json_qs "$x")"); done
                if [ "${#out[@]}" -gt 0 ]; then json_arr "${out[@]}"; else printf '[]'; fi; }
    hos=(); i=0
    while [ "$i" -lt "${#HO_IDS[@]}" ]; do
        hos+=("$(json_obj "handoff.id" "$(json_qs "${HO_IDS[$i]}")" "handoff.cycle" "$(json_qs "${HO_CYCLES[$i]}")")")
        i=$((i + 1))
    done
    cs=(); i=0
    while [ "$i" -lt "${#C_IDS[@]}" ]; do
        cs+=("$(json_obj id "$(json_qs "${C_IDS[$i]}")" severity "$(json_qs "${C_SEVS[$i]}")" rule "$(json_qs "${C_RULES[$i]}")")")
        i=$((i + 1))
    done
    if [ "${#hos[@]}" -gt 0 ]; then ho_json=$(json_arr "${hos[@]}"); else ho_json="[]"; fi
    if [ "${#cs[@]}" -gt 0 ]; then c_json=$(json_arr "${cs[@]}"); else c_json="[]"; fi
    nullable() { if [ -n "$1" ]; then json_qs "$1"; else printf 'null'; fi; }
    json_emit pr-body "$(json_obj \
        "task.id" "$(json_qs "$SPEC_ID")" \
        "task.cycle" "$(nullable "$CYCLE")" \
        "project.id" "$(nullable "$PROJECT")" \
        "project.stage" "$(nullable "$STAGE")" \
        title "$(json_qs "$PR_TITLE")" \
        handoffs "$ho_json" \
        decisions_referenced "$(qs_list "${DECS[@]:-}")" \
        decisions_new "$(qs_list "${NEW_DECS[@]:-}")" \
        constraints "$c_json" \
        base "$(nullable "$BASE_DESC")" \
        changed_files "${#CHANGED[@]}")"
    exit 0
fi

# Plain markdown, no colour codes: this is pasted into a PR.
printf '<!-- generated by `just pr-body %s %s`; suggested title: %s -->\n' "$SPEC_ID" "$CYCLE" "$PR_TITLE"
printf '## %s: %s\n\n' "$SPEC_ID" "$TITLE"
printf -- '- **Cycle:** %s\n' "${CYCLE:-?}"
printf -- '- **Project:** %s\n' "${PROJECT:-?}"
printf -- '- **Stage:** %s\n' "${STAGE:-?}"
printf -- '- **Spec:** %s\n' "$SPEC_ID"
if [ "${#HO_IDS[@]}" -gt 0 ]; then
    hl=(); i=0
    while [ "$i" -lt "${#HO_IDS[@]}" ]; do hl+=("${HO_IDS[$i]} (${HO_CYCLES[$i]:-?})"); i=$((i + 1)); done
    printf -- '- **Handoff:** %s\n' "$(join_or_none "${hl[@]}")"
fi
printf -- '- **Decisions referenced:** %s\n' "$(join_or_none "${DECS[@]:-}")"
if [ -n "$BASE_DESC" ]; then
    printf -- '- **New decisions:** %s\n' "$(join_or_none "${NEW_DECS[@]:-}")"
fi
printf '\n### Constraints to check\n\n'
if [ -z "$BASE_DESC" ]; then
    printf '_No diff base; run `just pr-body %s %s --base <ref>`._\n' "$SPEC_ID" "$CYCLE"
elif [ "${#C_IDS[@]}" -eq 0 ]; then
    printf '_No constraint'"'"'s paths match the %d files in %s._\n' "${#CHANGED[@]}" "$BASE_DESC"
else
    printf '_Constraints whose paths match the %d files in %s. Tick each one you checked._\n\n' "${#CHANGED[@]}" "$BASE_DESC"
    i=0
    while [ "$i" -lt "${#C_IDS[@]}" ]; do
        printf -- '- [ ] `%s` (%s): %s\n' "${C_IDS[$i]}" "${C_SEVS[$i]:-?}" "${C_RULES[$i]}"
        i=$((i + 1))
    done
fi
printf '\n### Summary\n\n<!-- what changed and why; the ids above are derived, the prose is yours -->\n'
