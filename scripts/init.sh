#!/usr/bin/env bash
# scripts/init.sh — scaffold one variant to the repo root (`just init`).
#
#   just init                       # interactive: pick a variant, then confirm
#   just init claude-plus-agents    # non-interactive, scriptable
#   just init claude-only           # deprecated (DEC-015); still works
#
# Init is one-shot: it copies variants/<name>/ over the root and deletes
# variants/, so the choice cannot be re-made from inside the tool. It used to
# take that step on a bare `read` with no confirmation, at the moment the user
# knew least about the difference (irradiance picked the wrong variant and
# recovered only because nothing was committed yet). So:
#   - with no argument, the choice is echoed back and must be confirmed;
#   - with an argument, the argument is the confirmation, and nothing is read
#     from stdin (the fresh-history offer is skipped too, since answering it
#     rewrites the history you would restore from).
#
# New instances use claude-plus-agents (DEC-015): it is listed first and is the
# default on Enter. claude-only still scaffolds, with a notice, because existing
# instances use it and template-update serves them from variants/claude-only.
#
# Deliberately does not source _lib.sh: before init this is the template repo,
# and nothing here needs more than echo.
#
# Exit status: 0 scaffolded · 1 refused or aborted · 2 usage error.
set -euo pipefail

usage() {
    echo "usage: just init [claude-plus-agents|claude-only]" >&2
    exit 2
}

deprecation_notice() {
    echo "⚠  claude-only is deprecated (DEC-015). New projects should use" >&2
    echo "   claude-plus-agents: same cycle and scripts, plus a handoff per build" >&2
    echo "   and verify, which works with Claude as every agent. Continuing." >&2
}

[ "$#" -le 1 ] || usage
ARG="${1:-}"

echo "Spec-driven repo template — init"
echo ""

if [ -f AGENTS.md ]; then
    echo "⚠  Already initialized (AGENTS.md exists at repo root)."
    echo "   Init is one-shot: it consumes variants/ when it runs."
    echo "   To start over, restore the repo from git or re-clone."
    exit 1
fi
if [ ! -d variants ]; then
    echo "⚠  variants/ directory is missing."
    echo "   This repo was already initialized (or the template was"
    echo "   modified). Restore from git or re-clone to re-init."
    exit 1
fi

case "$ARG" in
    claude-only|claude-plus-agents)
        VARIANT="$ARG"
        INTERACTIVE=0
        [ "$VARIANT" = claude-only ] && deprecation_notice
        ;;
    '')
        INTERACTIVE=1
        echo "Pick a variant:"
        echo "  1) claude-plus-agents  (recommended; build and verify each get a"
        echo "                          handoff, usually to a fresh Claude session)"
        echo "  2) claude-only         (deprecated; one session plays every role)"
        echo ""
        printf "Enter 1 or 2 [1]: "
        variant_choice=""
        # EOF here (no input at all) must not pick a default: an empty pipe is
        # not a choice. Only an answered empty line means "the default".
        read -r variant_choice || { echo ""; echo "Aborted — nothing was changed."; exit 1; }
        case "$variant_choice" in
            1|'') VARIANT="claude-plus-agents" ;;
            2) VARIANT="claude-only" ;;
            *) echo "Invalid choice: ${variant_choice}"; exit 1 ;;
        esac
        echo ""
        [ "$VARIANT" = claude-only ] && deprecation_notice
        echo "You chose: ${VARIANT}"
        echo "This copies variants/${VARIANT}/ to the repo root and deletes variants/"
        echo "(both variants). It cannot be re-run; undoing it means restoring from git."
        printf "Scaffold %s? [y/N]: " "$VARIANT"
        confirm=""
        read -r confirm || true
        case "$confirm" in
            y|Y|yes|YES) : ;;
            *) echo "Aborted — nothing was changed."; exit 1 ;;
        esac
        ;;
    *)
        echo "Unknown variant: ${ARG}" >&2
        usage
        ;;
esac

echo ""
echo "Scaffolding ${VARIANT} to repo root..."
cp -r "variants/${VARIANT}/." .
rm -rf variants/
echo "$VARIANT" > .variant
./scripts/scaffold-clean.sh
echo ""
echo "✓ Done. Your variant: ${VARIANT}"
echo ""

if [ "$INTERACTIVE" = 1 ]; then
    printf "Start with a fresh git history? (removes template history) [y/N]: "
    fresh_choice=""
    read -r fresh_choice || true
    if [ "$fresh_choice" = "y" ] || [ "$fresh_choice" = "Y" ]; then
        ./scripts/fresh-history.sh -y
    else
        echo "  (kept existing git history — run 'just fresh-start' later to reset)"
    fi
else
    echo "  (git history untouched — run 'just fresh-start' to reset it if you cloned)"
fi

echo ""
echo "Next steps:"
echo "  1. Open GETTING_STARTED.md"
echo "  2. Work through the PROJECT FRAME prompt in FIRST_SESSION_PROMPTS.md"
echo "  3. Commit your work (skip if you reset history above — that already"
echo "     made the first commit):  git add . && git commit -m 'chore: scaffold'"
