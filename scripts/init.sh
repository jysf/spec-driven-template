#!/usr/bin/env bash
# scripts/init.sh — scaffold one variant to the repo root (`just init`).
#
#   just init                       # interactive: pick a variant, then confirm
#   just init claude-only           # non-interactive, scriptable
#   just init claude-plus-agents
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
# Deliberately does not source _lib.sh: before init this is the template repo,
# and nothing here needs more than echo.
#
# Exit status: 0 scaffolded · 1 refused or aborted · 2 usage error.
set -euo pipefail

usage() {
    echo "usage: just init [claude-only|claude-plus-agents]" >&2
    exit 2
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
        ;;
    '')
        INTERACTIVE=1
        echo "Pick a variant:"
        echo "  1) claude-only         (Claude plays every role; simpler)"
        echo "  2) claude-plus-agents  (Claude architects, separate agent implements)"
        echo ""
        printf "Enter 1 or 2: "
        variant_choice=""
        read -r variant_choice || true
        case "$variant_choice" in
            1) VARIANT="claude-only" ;;
            2) VARIANT="claude-plus-agents" ;;
            *) echo "Invalid choice: ${variant_choice}"; exit 1 ;;
        esac
        echo ""
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
