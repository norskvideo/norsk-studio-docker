#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")/.."
source test/common.sh
set +e

echo "Testing up.sh workflow/overrides validation..."
echo ""

# Test 1: --workflow requires argument
output=$(run_expect_fail ./up.sh --workflow)
assert_contains "$output" "--workflow requires" \
    "Reject --workflow without argument"

# Test 2: --workflow file must exist
output=$(run_expect_fail ./up.sh --workflow nonexistent.yaml --merge /tmp/test.yaml)
assert_contains "$output" "not found" \
    "Reject --workflow with nonexistent file"

# Test 3: --workflow rejects paths outside studio-save-files
output=$(run_expect_fail ./up.sh --workflow /etc/passwd --merge /tmp/test.yaml)
assert_contains "$output" "must be in" \
    "Reject --workflow with path outside studio-save-files"

# Test 4: --workflow rejects relative paths with directories
output=$(run_expect_fail ./up.sh --workflow ../foo/bar.yaml --merge /tmp/test.yaml)
assert_contains "$output" "must be in" \
    "Reject --workflow with relative path containing directories"

# Test 5: --workflow accepts valid file (using existing workflow)
output=$(./up.sh --workflow 01-SRT-to-HLS-Ladder.yaml --merge /tmp/test.yaml 2>&1)
assert_contains "$output" "STUDIO_DOCUMENT" \
    "Accept --workflow with valid file"

# Test 6: --overrides requires argument
output=$(run_expect_fail ./up.sh --overrides)
assert_contains "$output" "--overrides requires" \
    "Reject --overrides without argument"

# Test 7: --overrides file must exist
output=$(run_expect_fail ./up.sh --overrides nonexistent.yaml --merge /tmp/test.yaml)
assert_contains "$output" "not found" \
    "Reject --overrides with nonexistent file"

rm -f /tmp/test.yaml
test_summary
