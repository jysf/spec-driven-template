#!/usr/bin/env bash
# scripts/template-update.sh — bring an instance's template-managed files up to
# this template's version.
#
#   ./scripts/template-update.sh ~/path/to/instance            # dry run: report only
#   ./scripts/template-update.sh --apply ~/path/to/instance    # write the update
#   ./scripts/template-update.sh --base 0.6.30 ~/path/...      # instance has no VERSION
#   ./scripts/template-update.sh --json ~/path/to/instance
#   ./scripts/template-update.sh --apply --take scripts/_lib.sh ~/path/...
#                                   # you reviewed the conflict: use the template's copy
#
# Why: `just init` copies a variant once, and nothing afterwards brings template
# fixes in. Measured 2026-11-09 over nine instances: the five with a VERSION
# file each held 22-26 template files they had never edited, still at their
# scaffold version, and only 1-10 files with local edits. The edits are why
# this cannot be a plain copy; the VERSION is what makes it more than one.
#
# How: a three-way update per file, like a git merge. The base is this
# template's own history at the instance's VERSION (the commit, among those
# carrying that version, whose files match the instance best). For each
# template-managed file:
#   current   the instance already has the template's copy
#   update    unedited since the base — replaced with the template's copy
#   add       new in the template since the base
#   merge     edited here AND upstream — merged cleanly (git merge-file)
#   conflict  edited here AND upstream, and the merge conflicts (or a merged
#             script fails `bash -n`). Never written
#             into the instance; the draft with conflict markers is saved
#             outside it and its path printed.
#   kept      edited here; the template has not changed it since the base
#   deleted   the instance removed it; left removed
#   removed   the template removed it; reported, left in place
#   take      you passed --take for it: the template's copy replaces yours
#   held      would apply, but scripts/ and the justfile move as one unit and
#             something in that unit can't (see "scripts move together")
#   diverged  no base copy to compare against (an instance file with the same
#             name, or a guessed base); reported, never written
# Files the instance owns (AGENTS.md, guidance/, .repo-context.yaml, …) are
# never written; when the template changed one since the base it is listed as a
# notice with the command that shows the change.
#
# Run from the template repo, against a checkout on disk, like
# instances-diff.sh: an instance has no copy of the template to update from.
# It uses the template's COMMITTED HEAD, not its working tree.
#
# --apply refuses on a dirty instance working tree: the undo for an update is
# `git checkout`/`git restore` in the instance, and uncommitted work there would
# be mixed into it. Only a COMPLETE update (no conflicts, nothing held) writes
# the template's version to the instance's VERSION: that file is the next run's
# base.
#
# Exit status: 0 ok (or dry run) · 1 refused, or --apply was partial ·
# 2 usage error.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

USAGE="./scripts/template-update.sh [--apply] [--json] [--base X.Y.Z] [--take PATH]... <instance-path>"
APPLY=0; JSON_OUT=0; BASE_VERSION=""; INST=""; TAKE=" "
while [ "$#" -gt 0 ]; do
    case "$1" in
        --apply)   APPLY=1 ;;
        --json)    JSON_OUT=1 ;;
        --base)    BASE_VERSION="${2:-}"; [ -n "$BASE_VERSION" ] || usage_error "$USAGE"; shift ;;
        --base=*)  BASE_VERSION="${1#--base=}" ;;
        --take)    [ -n "${2:-}" ] || usage_error "$USAGE"; TAKE="${TAKE}${2} "; shift ;;
        --take=*)  TAKE="${TAKE}${1#--take=} " ;;
        -*)        usage_error "$USAGE" ;;
        '')        : ;;
        *)         [ -z "$INST" ] || usage_error "$USAGE"; INST="$1" ;;
    esac
    shift
done
[ -n "$INST" ] || usage_error "$USAGE"

TPL="$(cd "${SCRIPT_DIR}/.." && pwd)"
[ -d "${TPL}/variants" ] || die "Run this from the template repo (no variants/ at ${TPL}). An instance has no template copy to update from."
[ -d "$INST" ] || die "Not a directory: ${INST}"
INST="$(cd "$INST" && pwd)"
[ "$INST" != "$TPL" ] || die "That is the template repo itself; point this at an instance."
git -C "$INST" rev-parse --git-dir >/dev/null 2>&1 || die "Not a git repo: ${INST} (the update's undo is git, so it needs one)."

tg() { git -C "$TPL" "$@"; }
HEAD_REV=$(tg rev-parse HEAD)
HEAD_VERSION=$(tg show "HEAD:VERSION" 2>/dev/null | tr -d ' \t\n\r')
if [ -n "$(tg status --porcelain 2>/dev/null)" ] && [ "$JSON_OUT" = 0 ]; then
    warn "The template has uncommitted changes; they are ignored (this uses its committed HEAD, ${HEAD_REV:0:7})."
fi

# --- variant -----------------------------------------------------------------
VARIANT=$(tr -d ' \t\n\r' < "${INST}/.variant" 2>/dev/null || true)
if [ -z "$VARIANT" ]; then
    if [ -f "${INST}/projects/_templates/handoff.md" ]; then VARIANT="claude-plus-agents"; else VARIANT="claude-only"; fi
fi
case "$VARIANT" in
    claude-only|claude-plus-agents) : ;;
    *) die "Unknown variant '${VARIANT}' in ${INST}/.variant" ;;
esac

# --- which files the template owns -------------------------------------------
# Emits "instance-path<TAB>template-path<TAB>blob-sha<TAB>mode" for one commit.
# Owned by the template: the shared scripts and justfile (the justfile says so
# in its banner; the app's recipes live in app.just), the variant's
# projects/_templates/, its decisions/_template.md, its reference docs and its
# CI workflows. Not test.sh, instances-diff.sh or this script (maintainer
# tools), nor init.sh (it only runs before init).
REF_DOCS="cost-tracking.md schema-reference.md porting.md versioning.md signals.md license-policy.md CONTEXTCORE_ALIGNMENT.md"
managed_files() {
    tg ls-tree -r "$1" | awk -F'\t' -v v="variants/${VARIANT}/" -v docs=" ${REF_DOCS} " '
        {
            split($1, m, " "); mode = m[1]; sha = m[3]; p = $2
            ip = ""
            if (p ~ /^scripts\/[^\/]+\.sh$/ && p != "scripts/test.sh" &&
                p != "scripts/instances-diff.sh" && p != "scripts/template-update.sh" &&
                p != "scripts/init.sh") ip = p
            else if (p == "justfile") ip = p
            else if (index(p, v) == 1) {
                r = substr(p, length(v) + 1)
                if (r ~ /^projects\/_templates\//) ip = r
                else if (r == "decisions/_template.md") ip = r
                else if (r ~ /^\.github\/workflows\//) ip = r
                else if (r ~ /^docs\/[^\/]+$/ && index(docs, " " substr(r, 6) " ") > 0) ip = r
            }
            if (ip != "") printf "%s\t%s\t%s\t%s\n", ip, p, sha, mode
        }'
}
# Instance-owned files the template also ships: never written, but a change
# upstream is worth knowing about.
OWNED="AGENTS.md CLAUDE.md GETTING_STARTED.md FIRST_SESSION_PROMPTS.md .repo-context.yaml guidance/constraints.yaml"

WORK=$(mktemp -d 2>/dev/null || mktemp -d -t template-update)
trap 'rm -rf "$WORK"' EXIT
managed_files "$HEAD_REV" > "$WORK/head.tsv"

# Hash every instance file the template could own, once.
inst_hashes() {   # reads instance paths on stdin, prints "path<TAB>sha" for those that exist
    while IFS= read -r p; do
        [ -f "${INST}/${p}" ] && printf '%s\t%s\n' "$p" "$(git hash-object "${INST}/${p}")"
    done
    return 0
}

# --- the base: this template at the instance's version ------------------------
BASE_HOW=""
[ -n "$BASE_VERSION" ] && BASE_HOW="--base"
if [ -z "$BASE_VERSION" ] && [ -f "${INST}/VERSION" ]; then
    BASE_VERSION=$(tr -d ' \t\n\r' < "${INST}/VERSION")
    BASE_HOW="VERSION"
fi

BASE_REV=""; BASE_MATCH=0; BASE_TOTAL=0
if [ -n "$BASE_VERSION" ]; then
    # Commits (first-parent) that carry exactly BASE_VERSION: from the one that
    # set it up to, not including, the one that changed it next.
    set_rev=""; next_rev=""
    while IFS= read -r c; do
        v=$(tg show "${c}:VERSION" 2>/dev/null | tr -d ' \t\n\r' || true)
        if [ "$v" = "$BASE_VERSION" ]; then set_rev="$c"; break; fi
        next_rev="$c"
    done < <(tg log --first-parent --format=%H HEAD -- VERSION)
    [ -n "$set_rev" ] || die "The template's history has no version ${BASE_VERSION} (from ${BASE_HOW}). Pass --base with one it has: $(tg log --first-parent --format=%H HEAD -- VERSION | while read -r c; do tg show "${c}:VERSION" 2>/dev/null; done | tr -d '\r' | sort -t. -k1,1n -k2,2n -k3,3n | uniq | tr '\n' ' ')"
    if [ -n "$next_rev" ]; then
        candidates=$(tg rev-list --first-parent --max-count=60 "${next_rev}^" "^${set_rev}^" 2>/dev/null || true)
    else
        candidates=$(tg rev-list --first-parent --max-count=60 HEAD "^${set_rev}^" 2>/dev/null || true)
    fi
    [ -n "$candidates" ] || candidates="$set_rev"
    # The instance was scaffolded from one of these; take the one whose files it
    # still matches most (ties go to the newest).
    best=-1
    for c in $candidates; do
        managed_files "$c" > "$WORK/cand.tsv"
        cut -f1 "$WORK/cand.tsv" | inst_hashes > "$WORK/cand-inst.tsv"
        n=$(awk -F'\t' 'NR == FNR { h[$1] = $2; next } ($1 in h) && h[$1] == $3 { n++ } END { print n + 0 }' \
            "$WORK/cand-inst.tsv" "$WORK/cand.tsv")
        if [ "$n" -gt "$best" ]; then
            best=$n; BASE_REV=$c; BASE_TOTAL=$(grep -c . "$WORK/cand.tsv" || true)
        fi
    done
    BASE_MATCH=$best
    managed_files "$BASE_REV" > "$WORK/base.tsv"
else
    : > "$WORK/base.tsv"
fi

cut -f1 "$WORK/head.tsv" "$WORK/base.tsv" | sort -u | inst_hashes > "$WORK/inst.tsv"

# --- classify ----------------------------------------------------------------
# One row per path: action<TAB>instance-path<TAB>template-path-at-HEAD<TAB>template-path-at-base<TAB>mode
# An empty field is written as "-": tab is IFS whitespace, so `read` would
# collapse two tabs in a row and shift every later field (it lost the mode of
# newly added scripts, which then arrived non-executable).
awk -F'\t' -v hasbase="$([ -n "$BASE_REV" ] && echo 1 || echo 0)" '
    FILENAME == ARGV[1] { hp[$1] = $2; hs[$1] = $3; hm[$1] = $4; order[++n] = $1; next }
    FILENAME == ARGV[2] { bp[$1] = $2; bs[$1] = $3; if (!($1 in hs)) border[++nb] = $1; next }
    FILENAME == ARGV[3] { is[$1] = $2; next }
    END {
        for (i = 1; i <= n; i++) {
            p = order[i]; have = (p in is); based = (p in bs)
            if (have && is[p] == hs[p])            a = "current"
            else if (!have && !based)              a = "add"
            else if (!have)                        a = "deleted"
            else if (!based)                       a = (hasbase ? "diverged" : "differs")
            else if (bs[p] == hs[p])               a = "kept"
            else if (is[p] == bs[p])               a = "update"
            else                                   a = "merge?"
            printf "%s\t%s\t%s\t%s\t%s\n", a, p, hp[p], (based ? bp[p] : "-"), hm[p]
        }
        for (i = 1; i <= nb; i++) {
            p = border[i]
            if ((p in is) && is[p] == bs[p]) printf "removed\t%s\t-\t%s\t-\n", p, bp[p]
        }
    }' "$WORK/head.tsv" "$WORK/base.tsv" "$WORK/inst.tsv" > "$WORK/plan.tsv"

# Try every three-way merge now, so a dry run already knows merge from conflict.
DRAFTS=""
: > "$WORK/plan2.tsv"
while IFS="$(printf '\t')" read -r a p hpath bpath mode; do
    if [ "$a" = "merge?" ]; then
        tg show "${BASE_REV}:${bpath}" > "$WORK/b"
        tg show "${HEAD_REV}:${hpath}" > "$WORK/t"
        mkdir -p "$WORK/merged/$(dirname "$p")"
        rc=0
        git merge-file -p -L "${p} (instance)" -L "${p} (template ${BASE_VERSION})" -L "${p} (template ${HEAD_VERSION})" \
            "${INST}/${p}" "$WORK/b" "$WORK/t" > "$WORK/merged/${p}" 2>/dev/null || rc=$?
        # A merge with no textual conflict can still be broken bash (two edits
        # that each assumed the other was absent). Syntax-check merged scripts;
        # one that fails is treated as a conflict.
        if [ "$rc" -eq 0 ] && [ "${p%.sh}" != "$p" ] && ! bash -n "$WORK/merged/${p}" 2>/dev/null; then
            rc=1
        fi
        if [ "$rc" -eq 0 ]; then
            a="merge"
        else
            a="conflict"
            if [ -z "$DRAFTS" ]; then
                DRAFTS=$(mktemp -d 2>/dev/null || mktemp -d -t template-update-drafts)
            fi
            mkdir -p "${DRAFTS}/$(dirname "$p")"
            cp "$WORK/merged/${p}" "${DRAFTS}/${p}"
        fi
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$a" "$p" "$hpath" "$bpath" "$mode" >> "$WORK/plan2.tsv"
done < "$WORK/plan.tsv"

# --take: the template's copy, by the user's explicit choice, for a file they
# reviewed (typically an instance fix for a bug the template has since fixed).
if [ "$TAKE" != " " ]; then
    for tp in $TAKE; do
        awk -F'\t' -v p="$tp" '$2 == p { f = 1 } END { exit !f }' "$WORK/plan2.tsv" \
            || usage_error "--take ${tp}: not a template-managed file in this instance (see the report's paths)"
    done
    awk -F'\t' -v take="$TAKE" 'BEGIN { OFS = "\t" }
        index(take, " " $2 " ") && $3 != "-" && $1 != "current" && $1 != "update" && $1 != "add" { $1 = "take" }
        { print }' "$WORK/plan2.tsv" > "$WORK/plan3.tsv"
    mv "$WORK/plan3.tsv" "$WORK/plan2.tsv"
fi

# --- scripts move together ---------------------------------------------------
# Every script sources _lib.sh, so a new script beside an old library breaks:
# on irradiance, a partial update left status.sh calling a has_projects() the
# old _lib.sh lacks, and cost-audit, hitting the same missing function, passed
# its gate as if the repo had no projects. So scripts/ and the justfile are one
# unit. Build the set of scripts the instance would end up with, and if any of
# them calls a library function the resulting _lib.sh does not define (or
# _lib.sh itself can't be applied), hold back every script and justfile change.
HOLD_REASON=""
mkdir -p "$WORK/final"
while IFS="$(printf '\t')" read -r a p hpath _ _; do
    case "$p" in scripts/*.sh) : ;; *) continue ;; esac
    case "$a" in
        update|add|take) tg show "${HEAD_REV}:${hpath}" > "$WORK/final/$(basename "$p")" ;;
        merge)      cp "$WORK/merged/${p}" "$WORK/final/$(basename "$p")" ;;
        deleted)    : ;;
        *)          [ -f "${INST}/${p}" ] && cp "${INST}/${p}" "$WORK/final/$(basename "$p")" ;;
    esac
done < "$WORK/plan2.tsv"
# Instance-only scripts source the library too.
for f in "${INST}"/scripts/*.sh; do
    [ -f "$f" ] || continue
    [ -f "$WORK/final/$(basename "$f")" ] || cp "$f" "$WORK/final/"
done

lib_action=$(awk -F'\t' '$2 == "scripts/_lib.sh" { print $1; exit }' "$WORK/plan2.tsv")
case "$lib_action" in
    conflict|diverged|differs) HOLD_REASON="scripts/_lib.sh could not be updated (${lib_action})" ;;
esac
if [ -z "$HOLD_REASON" ] && [ -f "$WORK/final/_lib.sh" ]; then
    # Library function names, from every version in play: a script calling one
    # the final library lacks is the break. Comments are stripped first.
    { tg show "${HEAD_REV}:scripts/_lib.sh" 2>/dev/null || true
      [ -n "$BASE_REV" ] && { tg show "${BASE_REV}:scripts/_lib.sh" 2>/dev/null || true; }
      cat "${INST}/scripts/_lib.sh" 2>/dev/null || true
    } | awk '/^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/ { sub(/[[:space:]]*\(\).*/, ""); print }' \
      | sort -u > "$WORK/lib-vocab.txt"
    awk '/^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/ { sub(/[[:space:]]*\(\).*/, ""); print }' \
        "$WORK/final/_lib.sh" | sort -u > "$WORK/lib-final.txt"
    broken=""
    for f in "$WORK"/final/*.sh; do
        [ "$(basename "$f")" = "_lib.sh" ] && continue
        miss=$(awk -v vocab="$WORK/lib-vocab.txt" -v fin="$WORK/lib-final.txt" '
            BEGIN {
                while ((getline w < vocab) > 0) v[w] = 1
                while ((getline w < fin) > 0) d[w] = 1
            }
            { line = $0; sub(/(^|[[:space:]])#.*$/, "", line) }
            line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/ {
                n = line; sub(/^[[:space:]]*/, "", n); sub(/[[:space:]]*\(\).*/, "", n); own[n] = 1
            }
            { k = split(line, t, /[^A-Za-z0-9_]+/); for (i = 1; i <= k; i++) if (t[i] in v) used[t[i]] = 1 }
            END { for (u in used) if (!(u in d) && !(u in own)) printf "%s ", u }
        ' "$f")
        [ -z "$miss" ] || broken="${broken} $(basename "$f") (${miss% })"
    done
    [ -z "$broken" ] || HOLD_REASON="these scripts would call functions the resulting _lib.sh does not define:${broken}"
fi
if [ -n "$HOLD_REASON" ]; then
    awk -F'\t' 'BEGIN { OFS = "\t" }
        ($2 ~ /^scripts\/[^\/]+\.sh$/ || $2 == "justfile") && ($1 == "update" || $1 == "add" || $1 == "merge" || $1 == "take") { $1 = "held" }
        { print }' "$WORK/plan2.tsv" > "$WORK/plan3.tsv"
    mv "$WORK/plan3.tsv" "$WORK/plan2.tsv"
fi

# Owned files the template changed since the base.
: > "$WORK/notice.tsv"
if [ -n "$BASE_REV" ]; then
    for o in $OWNED; do
        tp="variants/${VARIANT}/${o}"
        hb=$(tg rev-parse -q --verify "${HEAD_REV}:${tp}" 2>/dev/null || true)
        bb=$(tg rev-parse -q --verify "${BASE_REV}:${tp}" 2>/dev/null || true)
        if [ -n "$hb" ] && [ "$hb" != "$bb" ]; then
            printf '%s\t%s\n' "$o" "$tp" >> "$WORK/notice.tsv"
        fi
    done
fi

count() { awk -F'\t' -v a="$1" '$1 == a { n++ } END { print n + 0 }' "$WORK/plan2.tsv"; }
N_CONFLICT=$(count conflict)

# --- apply -------------------------------------------------------------------
APPLIED=0; VERSION_BUMPED=0
if [ "$APPLY" = 1 ]; then
    [ -n "$BASE_REV" ] || die "${INST} has no VERSION, so there is no base to tell its edits from the template's. Pass --base X.Y.Z if you know the version it was scaffolded from; otherwise use the report."
    if [ -n "$(git -C "$INST" status --porcelain 2>/dev/null)" ]; then
        die "${INST} has uncommitted changes. Commit or stash them first: the update's undo is git, and it should not be mixed with other work."
    fi
    while IFS="$(printf '\t')" read -r a p hpath _ mode; do
        case "$a" in
            update|add|take)
                mkdir -p "$(dirname "${INST}/${p}")"
                tg show "${HEAD_REV}:${hpath}" > "${INST}/${p}"
                [ "$mode" = "100755" ] && chmod +x "${INST}/${p}"
                ;;
            merge)
                cp "$WORK/merged/${p}" "${INST}/${p}"
                [ "$mode" = "100755" ] && chmod +x "${INST}/${p}"
                ;;
        esac
    done < "$WORK/plan2.tsv"
    # VERSION is the base for the next run, so it moves only when the update is
    # complete. Bumped over a partial update, the next run would read every file
    # still at the old version as a local edit.
    if [ "$N_CONFLICT" -eq 0 ] && [ -z "$HOLD_REASON" ]; then
        printf '%s\n' "$HEAD_VERSION" > "${INST}/VERSION"
        VERSION_BUMPED=1
    fi
    APPLIED=1
fi

# --- report ------------------------------------------------------------------
ACTIONS="update add merge take conflict held kept deleted removed diverged differs current"
if [ "$JSON_OUT" = 1 ]; then
    files=()
    while IFS="$(printf '\t')" read -r a p _ _ _; do
        [ "$a" = current ] && continue
        draft="null"
        [ "$a" = conflict ] && draft=$(json_qs "${DRAFTS}/${p}")
        files+=("$(json_obj path "$(json_qs "$p")" action "$(json_qs "$a")" draft "$draft")")
    done < "$WORK/plan2.tsv"
    notices=()
    while IFS="$(printf '\t')" read -r o tp; do
        [ -n "$o" ] || continue
        notices+=("$(json_obj path "$(json_qs "$o")" \
            review "$(json_qs "git -C ${TPL} diff ${BASE_REV:0:12} ${HEAD_REV:0:12} -- ${tp}")")")
    done < "$WORK/notice.tsv"
    counts=()
    for a in $ACTIONS; do counts+=("$a" "$(count "$a")"); done
    json_emit template-update "$(json_obj \
        instance "$(json_qs "$INST")" variant "$(json_qs "$VARIANT")" \
        base_version "$([ -n "$BASE_VERSION" ] && json_qs "$BASE_VERSION" || echo null)" \
        base_commit "$([ -n "$BASE_REV" ] && json_qs "$BASE_REV" || echo null)" \
        base_files_matched "$BASE_MATCH" \
        template_version "$(json_qs "$HEAD_VERSION")" template_commit "$(json_qs "$HEAD_REV")" \
        applied "$([ "$APPLIED" = 1 ] && echo true || echo false)" \
        version_bumped "$([ "$VERSION_BUMPED" = 1 ] && echo true || echo false)" \
        scripts_held "$([ -n "$HOLD_REASON" ] && json_qs "$HOLD_REASON" || echo null)" \
        counts "$(json_obj "${counts[@]}")" \
        files "$(json_arr ${files[@]+"${files[@]}"})" \
        owned_changed_upstream "$(json_arr ${notices[@]+"${notices[@]}"})")"
    [ "$APPLIED" = 1 ] && [ "$VERSION_BUMPED" = 0 ] && exit 1
    exit 0
fi

echo "${BOLD}Template update: ${INST}${RESET} ${DIM}(${VARIANT})${RESET}"
if [ -n "$BASE_REV" ]; then
    echo "  base ${BASE_VERSION} ${DIM}(from ${BASE_HOW}; commit ${BASE_REV:0:7}, ${BASE_MATCH} of ${BASE_TOTAL} files match)${RESET} → template ${HEAD_VERSION} ${DIM}(${HEAD_REV:0:7})${RESET}"
else
    echo "  ${YELLOW}no VERSION file${RESET} → template ${HEAD_VERSION}"
    echo "  ${DIM}Without a base, local edits can't be told from template changes, so this is a"
    echo "  comparison only. Pass --base X.Y.Z if you know the scaffold version.${RESET}"
fi
echo ""
describe() {
    case "$1" in
        update)   echo "unedited since ${BASE_VERSION} — replaced with the template's copy" ;;
        add)      echo "new in the template" ;;
        merge)    echo "edited here and upstream — merged cleanly" ;;
        conflict) echo "edited here and upstream — conflicts; NOT applied" ;;
        held)     echo "held back: scripts and justfile move together (see below)" ;;
        take)     echo "the template's copy, as you asked (--take)" ;;
        kept)     echo "edited here; template unchanged since ${BASE_VERSION} — left alone" ;;
        deleted)  echo "removed here — left removed" ;;
        removed)  echo "removed from the template — left in place; delete it if unused" ;;
        diverged) echo "no base copy to compare — left alone" ;;
        differs)  echo "differs from the template" ;;
        current)  echo "already the template's copy" ;;
    esac
}
for a in $ACTIONS; do
    n=$(count "$a")
    [ "$n" -gt 0 ] || continue
    printf "  %-9s %3d  ${DIM}%s${RESET}\n" "$a" "$n" "$(describe "$a")"
done
echo ""
for a in update add merge take conflict held removed diverged differs; do
    awk -F'\t' -v a="$a" '$1 == a { printf "  %-9s %s\n", a, $2 }' "$WORK/plan2.tsv"
done
if [ -n "$HOLD_REASON" ]; then
    echo ""
    echo "  ${YELLOW}⚠${RESET} Script changes held back: ${HOLD_REASON}."
    echo "    ${DIM}Resolve that, then re-run; the held files apply together with it.${RESET}"
fi
if [ "$N_CONFLICT" -gt 0 ]; then
    echo ""
    echo "  ${YELLOW}⚠${RESET} Merged drafts with conflict markers, for the conflicts above: ${DRAFTS}"
    echo "    ${DIM}Resolve one by hand and copy it into the instance, or, if the template's copy"
    echo "    is what you want (often: your fix for a bug the template has since fixed),"
    echo "    re-run with --take <path>.${RESET}"
fi
if [ -s "$WORK/notice.tsv" ]; then
    echo ""
    echo "  ${BOLD}Yours, but changed in the template since ${BASE_VERSION}${RESET} ${DIM}(never written; review and port what you want):${RESET}"
    while IFS="$(printf '\t')" read -r o tp; do
        echo "    ${o}   ${DIM}git -C ${TPL} diff ${BASE_REV:0:7} ${HEAD_REV:0:7} -- ${tp}${RESET}"
    done < "$WORK/notice.tsv"
fi
echo ""
if [ "$APPLIED" = 1 ]; then
    if [ "$VERSION_BUMPED" = 1 ]; then
        success "Applied. VERSION is now ${HEAD_VERSION}. Review with 'git -C ${INST} diff', run its 'just validate', then commit."
    else
        warn "Applied in part. VERSION stays ${BASE_VERSION}, so a re-run after you resolve the above still knows the base."
        echo "  ${DIM}Review with 'git -C ${INST} diff'. Commit what applied, or not: a re-run picks up from either.${RESET}"
        exit 1
    fi
else
    echo "${DIM}Dry run — nothing written. Re-run with --apply to write the update.${RESET}"
fi
exit 0
