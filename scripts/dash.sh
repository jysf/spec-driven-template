#!/usr/bin/env bash
# scripts/dash.sh — one read command, many lenses (DEC-001 §4).
#
# The antidote to view sprawl: the now/next/future/ledger lenses ARE the
# existing read views (which keep working as their own commands — permanent
# aliases), and `just dash` with no argument stitches a single overview.
#
# The rule this enforces: when you want a slightly different slice, add a LENS
# here — never a new script.
#
#   just dash            stitched dashboard: now + future + cost + governance flags
#   just dash now        where are things now?            (= just status)
#   just dash next       what are we NOT working on next? (= just backlog)
#   just dash future     what's coming?                   (= just roadmap)
#   just dash ledger     every spec, all history          (= just specs-by-stage)
#   just dash decisions  browse DEC-* (confidence, superseded, scope)
#   just dash questions  open questions (what's blocking)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

require_initialized

# Lenses pass any remaining flags (e.g. --json) through to the underlying view.
lens="${1:-}"
case "$lens" in
    now)       shift; exec "${SCRIPT_DIR}/status.sh" "$@" ;;
    next)      shift; exec "${SCRIPT_DIR}/backlog.sh" "$@" ;;
    future)    shift; exec "${SCRIPT_DIR}/roadmap.sh" "$@" ;;
    ledger)    shift; exec "${SCRIPT_DIR}/specs-by-stage.sh" "$@" ;;
    decisions) shift; exec "${SCRIPT_DIR}/decisions-view.sh" "$@" ;;
    questions) shift; exec "${SCRIPT_DIR}/questions-view.sh" "$@" ;;
    help|-h|--help)
        cat <<'EOF'
just dash [lens] [--json]
  (no lens)  stitched dashboard: now + future + recorded cost + governance flags
  now        where are things now?             (= just status)
  next       what are we NOT working on next?  (= just backlog)
  future     what's coming?                    (= just roadmap)
  ledger     every spec, all history           (= just specs-by-stage)
  decisions  browse DEC-* (confidence, active/superseded, scope)
  questions  open questions from guidance/questions.yaml (what's blocking)
  --json     machine-readable output (works on the dashboard and every lens)
EOF
        exit 0 ;;
    ""|--json) : ;;  # no lens → stitched dashboard (human or, with --json, JSON)
    *)      die "Unknown lens: '$lens' (use: now | next | future | ledger | decisions | questions | help, or no arg for the dashboard)" ;;
esac

project=$(get_active_project)

# --- Default dashboard: JSON (stitches the status + roadmap reports + cost) ---
if [ "$(has_json_flag "$@")" = 1 ]; then
    now_json=$("${SCRIPT_DIR}/status.sh" --json)
    future_json=$("${SCRIPT_DIR}/roadmap.sh" --json)
    pdir="${REPO_ROOT}/projects/${project}"
    tot_usd="0.00"; tot_tok=0
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        case "$f" in *-timeline.md|*/prompts/*) continue ;; esac
        u=$(sum_cost_usd_for_spec "$f"); t=$(sum_cost_tokens_for_spec "$f")
        tot_usd=$(awk -v a="$tot_usd" -v b="$u" 'BEGIN{printf "%.2f", a+b}')
        tot_tok=$((tot_tok + t))
    done < <(find_all_specs "$pdir")
    cost=$(json_obj "cost.tokens_total" "$tot_tok" "cost.estimated_usd" "$tot_usd")
    flags=$(json_obj open_questions "$(count_open_questions)" low_confidence_decisions "$(count_low_confidence_decisions)")
    data=$(json_obj now "$now_json" future "$future_json" recorded_cost "$cost" flags "$flags")
    json_emit dash "$data"
    exit 0
fi

# --- Default: the stitched dashboard (human) -------------------------------
printf "${BOLD}=== Dashboard — %s ===${RESET}\n\n" "$project"

printf "${BOLD}▸ Now${RESET} ${DIM}(just dash now)${RESET}\n"
"${SCRIPT_DIR}/status.sh"
echo

printf "${BOLD}▸ Future${RESET} ${DIM}(just dash future)${RESET}\n"
"${SCRIPT_DIR}/roadmap.sh"
echo

# Recorded cost across the active project (reuses the cost lib — same numbers
# as `just specs-by-stage`'s grand total).
pdir="${REPO_ROOT}/projects/${project}"
tot_usd="0.00"; tot_tok=0
while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in *-timeline.md) continue ;; esac
    u=$(sum_cost_usd_for_spec "$f"); t=$(sum_cost_tokens_for_spec "$f")
    tot_usd=$(awk -v a="$tot_usd" -v b="$u" 'BEGIN{printf "%.2f", a+b}')
    tot_tok=$((tot_tok + t))
done < <(find_all_specs "$pdir")
printf "${BOLD}▸ Recorded cost${RESET}  \$%s · %s tokens  ${DIM}(just dash ledger for the full ledger)${RESET}\n" "$tot_usd" "$tot_tok"
echo

# Governance flags — things that should nag you, surfaced where you look.
oq=$(count_open_questions)
lcd=$(count_low_confidence_decisions)
if [ "$oq" -gt 0 ] || [ "$lcd" -gt 0 ]; then
    printf "${BOLD}▸ Flags${RESET}  ${YELLOW}⚠${RESET} %s open question(s) · %s decision(s) at confidence <0.7  ${DIM}(just dash questions | decisions)${RESET}\n" "$oq" "$lcd"
else
    printf "${BOLD}▸ Flags${RESET}  ${DIM}none — no open questions, no low-confidence decisions${RESET}\n"
fi
