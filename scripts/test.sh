#!/usr/bin/env bash
# scripts/test.sh — end-to-end happy-path test for the template.
#
# Copies the repo into a temp dir, runs `just init` + the full cycle
# (new-stage → new-spec → advance-cycle × 4 → archive-spec), and
# asserts the invariants that previous bugs tripped over:
#
#   - init is one-shot and refuses to re-run
#   - advance-cycle preserves the cycle legend comment
#   - archive-spec refuses to archive an already-archived spec
#   - weekly-review emits only repo-relative paths
#
# No external test framework needed. Prints PASS / FAIL per check.
# Exits 0 if everything passes, 1 on the first failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Colors (off if not a TTY) ---
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    GREEN=$(tput setaf 2 2>/dev/null || printf '')
    RED=$(tput setaf 1 2>/dev/null || printf '')
    DIM=$(tput dim 2>/dev/null || printf '')
    RESET=$(tput sgr0 2>/dev/null || printf '')
else
    GREEN=''; RED=''; DIM=''; RESET=''
fi

pass_count=0
fail_count=0

pass() {
    pass_count=$((pass_count + 1))
    echo "${GREEN}✓${RESET} $*"
}

fail() {
    fail_count=$((fail_count + 1))
    echo "${RED}✗${RESET} $*" >&2
    # Bail on first failure — later checks usually depend on earlier state.
    echo "" >&2
    echo "${RED}FAILED${RESET}  (${pass_count} passed before this one)" >&2
    echo "Scratch dir left at: ${SCRATCH}" >&2
    exit 1
}

assert_eq() {
    local actual="$1" expected="$2" msg="$3"
    if [ "$actual" = "$expected" ]; then
        pass "$msg"
    else
        fail "$msg (expected: '$expected', got: '$actual')"
    fi
}

assert_file() {
    if [ -f "$1" ]; then pass "file exists: $1"; else fail "missing file: $1"; fi
}

assert_no_file() {
    if [ ! -e "$1" ]; then pass "absent: $1"; else fail "unexpected path: $1"; fi
}

assert_contains() {
    local file="$1" pattern="$2" msg="$3"
    if grep -qE "$pattern" "$file"; then
        pass "$msg"
    else
        fail "$msg (pattern '$pattern' not found in $file)"
    fi
}

assert_cmd_fails() {
    local msg="$1"; shift
    if "$@" >/dev/null 2>&1; then
        fail "$msg (expected non-zero exit, got 0)"
    else
        pass "$msg"
    fi
}

# --- Set up scratch dir ---
SCRATCH=$(mktemp -d 2>/dev/null || mktemp -d -t 'template-hardening-test')
# Copy template into scratch/repo, then delete .git so the scratch acts
# like a fresh `Use this template` clone.
cp -R "$TEMPLATE_ROOT" "$SCRATCH/repo"
rm -rf "$SCRATCH/repo/.git"

cd "$SCRATCH/repo"
echo "${DIM}scratch: $SCRATCH${RESET}"
echo ""

# ============================================================
# 1) init: happy path
# ============================================================
printf "1\n" | just init >/dev/null 2>&1 \
    || fail "just init (claude-only) exited non-zero"
assert_file "AGENTS.md"
assert_file ".variant"
assert_eq "$(cat .variant)" "claude-only" "variant marker is claude-only"
assert_no_file "variants"
pass "init: scaffolded claude-only successfully"

# ============================================================
# 2) init: re-run guard
# ============================================================
assert_cmd_fails "re-running init (AGENTS.md present) fails" just init
rm AGENTS.md
assert_cmd_fails "init with variants/ gone also fails" bash -c 'printf "1\n" | just init'
# Restore AGENTS.md by rerunning init cleanly from a fresh scratch for the next checks.
# Simpler: copy AGENTS.md back from the TEMPLATE_ROOT's variant.
cp "$TEMPLATE_ROOT/variants/claude-only/AGENTS.md" ./AGENTS.md
pass "init: re-run guards work in both states"

# ============================================================
# 3) new-stage + new-spec scaffold correctly
# ============================================================
# Simulate the user replacing the REPLACE'd repo id in .repo-context.yaml
# so we can verify the scaffold picks it up.
sed_inplace_portable() {
    if [ "$(uname)" = "Darwin" ]; then sed -i '' "$@"; else sed -i "$@"; fi
}
sed_inplace_portable 's|id: my-app|id: bragfile-test|' .repo-context.yaml

just new-stage "Test Stage" >/dev/null
STAGE_FILE="projects/PROJ-001-example-mvp/stages/STAGE-002-test-stage.md"
assert_file "$STAGE_FILE"
# created_at should be today (not the __TODAY__ placeholder).
today=$(date +%Y-%m-%d)
assert_contains "$STAGE_FILE" "^created_at: ${today}\$" "stage.md created_at filled with today"
# target_complete comment should still say YYYY-MM-DD (not substituted).
assert_contains "$STAGE_FILE" "# optional: YYYY-MM-DD" "stage.md comment placeholder untouched"
# repo.id should come from .repo-context.yaml, not the hardcoded default.
assert_contains "$STAGE_FILE" "^  id: bragfile-test\$" "stage.md repo.id picks up from .repo-context.yaml"

just new-spec "Test Spec" STAGE-002 >/dev/null
SPEC_FILE="projects/PROJ-001-example-mvp/specs/SPEC-002-test-spec.md"
assert_file "$SPEC_FILE"
assert_contains "$SPEC_FILE" "id: SPEC-002" "spec ID set"
assert_contains "$SPEC_FILE" "stage: STAGE-002" "spec parent stage set"
assert_contains "$SPEC_FILE" "^  created_at: ${today}\$" "spec created_at filled"
assert_contains "$SPEC_FILE" "^  id: bragfile-test\$" "spec.md repo.id picks up from .repo-context.yaml"

# ============================================================
# 4) advance-cycle preserves the cycle legend comment
# ============================================================
just advance-cycle SPEC-002 build >/dev/null
assert_contains "$SPEC_FILE" "^  cycle: build.*# frame \| design \| build \| verify \| ship" \
    "advance-cycle build: cycle updated AND comment preserved"

just advance-cycle SPEC-002 verify >/dev/null
assert_contains "$SPEC_FILE" "^  cycle: verify.*# frame \| design" \
    "advance-cycle verify: cycle updated AND comment still present"

just advance-cycle SPEC-002 ship >/dev/null
assert_contains "$SPEC_FILE" "^  cycle: ship.*# frame \| design" \
    "advance-cycle ship: cycle updated AND comment still present"

# ============================================================
# 5) archive-spec: happy path + double-archive refusal
# ============================================================
archive_out=$(just archive-spec SPEC-002 2>&1)
ARCHIVED="projects/PROJ-001-example-mvp/specs/done/SPEC-002-test-spec.md"
assert_file "$ARCHIVED"
assert_no_file "$SPEC_FILE"
# The stage-shipped message must be an observation, not a completion
# claim — the stage's backlog may still list unwritten specs.
if printf '%s\n' "$archive_out" | grep -qE "All specs for .* are shipped\."; then
    fail "archive-spec prints false-positive 'All specs … are shipped' claim"
else
    pass "archive-spec does not claim stage completion"
fi
if printf '%s\n' "$archive_out" | grep -qE "No active specs remain for STAGE-002"; then
    pass "archive-spec reports observation (no active specs remain)"
else
    fail "archive-spec missing expected 'No active specs remain' message"
fi

# Second archive must fail and must NOT create done/done/...
assert_cmd_fails "double-archive of SPEC-002 fails" just archive-spec SPEC-002
assert_no_file "projects/PROJ-001-example-mvp/specs/done/done"

# advance-cycle on an archived spec must also fail.
assert_cmd_fails "advance-cycle on archived spec fails" just advance-cycle SPEC-002 build

# ============================================================
# 6) weekly-review emits only repo-relative paths
# ============================================================
review_out=$(just weekly-review 2>&1)
# The script's output should contain the scratch dir nowhere in path lines.
# It's OK for the scratch name to appear in shell echoes (it doesn't), but
# any `- /foo/...` bullet is a path bullet that must be relative.
if printf '%s\n' "$review_out" | grep -E "^- ${SCRATCH}" >/dev/null; then
    fail "weekly-review still prints absolute paths"
else
    pass "weekly-review: all bullet paths are repo-relative"
fi
# Sanity-check that it found the archived spec (relative).
if printf '%s\n' "$review_out" | grep -qE "^- projects/PROJ-001-example-mvp/specs/done/SPEC-002-test-spec\.md"; then
    pass "weekly-review: includes archived spec as relative path"
else
    fail "weekly-review: archived spec missing from output"
fi

# ============================================================
# 7) status runs cleanly post-archive
# ============================================================
just status >/dev/null 2>&1 || fail "just status exited non-zero after archive"
pass "status: clean exit after archive"

# ============================================================
# Done
# ============================================================
echo ""
echo "${GREEN}PASS${RESET}  ${pass_count} checks"
echo "${DIM}(scratch dir removed: ${SCRATCH})${RESET}"
rm -rf "$SCRATCH"
exit 0
