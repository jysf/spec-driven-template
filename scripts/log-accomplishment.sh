#!/usr/bin/env bash
# scripts/log-accomplishment.sh — record a shipped win WITH IMPACT (DEC-010).
#
# On by default. Pre-fills the configured accomplishment tool (default `brag`)
# from the spec's title + value_link + cost.totals, then runs it when the tool
# is present — otherwise prints the ready command so a human/agent can run it.
# Config: .repo-context.yaml → spec.accomplishments. Usage: log-win SPEC-NNN
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

require_initialized

ID="${1:-}"
[ -n "$ID" ] || die "Usage: just log-win SPEC-NNN"

enabled=$(get_accomplishments_field enabled true)
tool=$(get_accomplishments_field tool brag)

if [ "$enabled" != "true" ] || [ "$tool" = none ]; then
    info "Accomplishment logging is off (spec.accomplishments.enabled=${enabled}, tool=${tool}). Nothing to log."
    exit 0
fi

# Find the artifact (spec or patch), active or archived under done/.
FILE=$(find_spec "$ID" 2>/dev/null || true)
if [ -z "$FILE" ]; then
    FILE=$(find "${REPO_ROOT}/projects" -type f -name "${ID}-*.md" 2>/dev/null \
           | grep -v -- '-timeline' | head -n1)
fi
[ -n "$FILE" ] || die "Spec/patch not found: ${ID}"

title=$(awk '/^# (SPEC|PATCH)-[0-9]+:/ { sub(/^# [A-Z]+-[0-9]+:[[:space:]]*/, ""); print; exit }' "$FILE")
[ -n "$title" ] || title="${ID} shipped"
impact=$(extract_value_link "$FILE" 2>/dev/null || true)
[ -n "$impact" ] || impact="<IMPACT: who or what is better off, and by how much>"
usd=$(sum_cost_usd_for_spec "$FILE" 2>/dev/null || echo 0)
# Frame value-per-dollar when there's a real recorded spend.
case "$usd" in ''|0|0.00) : ;; *) impact="${impact} (~\$${usd} AI spend)" ;; esac
proj=$(get_repo_id)

if [ "$tool" = brag ]; then
    if command -v brag >/dev/null 2>&1; then
        entry=$(brag add -t "$title" -p "$proj" -k shipped -i "$impact" \
                    -d "Shipped ${ID}." 2>/dev/null) \
            && success "Logged brag entry ${entry}: ${title}" \
            || warn "brag add did not complete — run the command below by hand."
    else
        echo "brag is not installed. Install it, then run:"
    fi
    if ! command -v brag >/dev/null 2>&1; then
        printf '\n  brag add -t "%s" -p "%s" -k shipped \\\n    -i "%s"\n\n' "$title" "$proj" "$impact"
        echo "(Frame IMPACT as the outcome, not the output — guidance/recommended-tools.md.)"
    fi
else
    # A non-brag tool is configured — hand the fields over for it.
    echo "Configured accomplishment tool: ${tool} (see guidance/recommended-tools.md)."
    echo "  Title:  ${title}"
    echo "  Impact: ${impact}"
    echo "  Type:   shipped    Project: ${proj}"
fi
