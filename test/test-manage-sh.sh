#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")/.."
source test/common.sh
set +e

echo "Testing manage.sh..."
echo ""

# Test 1: --help works
output=$(./manage.sh --help)
assert_contains "$output" "Manage Norsk Studio releases" \
    "--help shows usage"

# Test 2: No args shows usage
output=$(./manage.sh)
assert_contains "$output" "Usage:" \
    "No args shows usage"

# Test 3: --current shows version info
output=$(./manage.sh --current 2>&1)
assert_contains "$output" "Release:" \
    "--current shows release info"
assert_contains "$output" "Containers:" \
    "--current shows container info"

# Test 4: Unknown option rejected
output=$(run_expect_fail ./manage.sh --unknown)
assert_contains "$output" "unknown option" \
    "Reject unknown option"

# Test 5: --use-containers requires arguments
output=$(run_expect_fail ./manage.sh --use-containers)
assert_contains "$output" "specify at least one" \
    "--use-containers requires media= or studio="

# Test 6: --use-containers rejects invalid format
output=$(run_expect_fail ./manage.sh --use-containers invalid)
assert_contains "$output" "unknown argument" \
    "--use-containers rejects invalid format"

test_summary
