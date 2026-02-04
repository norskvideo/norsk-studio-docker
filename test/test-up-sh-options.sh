#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")/.."
source test/common.sh
set +e

echo "Testing up.sh common options..."
echo ""

# Test 1: --logs requires argument
output=$(run_expect_fail ./up.sh --logs)
assert_contains "$output" "need to specify" \
    "Reject --logs without argument"

# Test 2: --working-directory requires argument
output=$(run_expect_fail ./up.sh --working-directory)
assert_contains "$output" "need to specify" \
    "Reject --working-directory without argument"

# Test 3: --working-directory rejects nonexistent directory
output=$(run_expect_fail ./up.sh --working-directory /nonexistent/path --merge /tmp/test.yaml)
assert_contains "$output" "does not exist" \
    "Reject --working-directory with nonexistent path"

# Test 4: --merge requires argument
output=$(run_expect_fail ./up.sh --merge)
assert_contains "$output" "needs an output file" \
    "Reject --merge without argument"

# Test 5: --merge rejects nonexistent directory
output=$(run_expect_fail ./up.sh --merge /nonexistent/dir/file.yaml)
assert_contains "$output" "does not exist" \
    "Reject --merge with nonexistent directory"

# Test 6: --turn requires true/false
output=$(run_expect_fail ./up.sh --turn maybe --merge /tmp/test.yaml)
assert_contains "$output" "true or false" \
    "Reject --turn with invalid value"

# Test 7: --turn true works (should include TURN config)
./up.sh --turn true --merge /tmp/test-turn.yaml > /dev/null 2>&1
((TESTS_RUN++))
if grep -q "norsk-turn" /tmp/test-turn.yaml 2>/dev/null; then
    pass "--turn true includes TURN config"
else
    fail "--turn true includes TURN config"
fi

# Test 8: --turn false works (no TURN)
./up.sh --turn false --merge /tmp/test-noturn.yaml > /dev/null 2>&1
((TESTS_RUN++))
if ! grep -q "norsk-turn" /tmp/test-noturn.yaml 2>/dev/null; then
    pass "--turn false excludes TURN config"
else
    fail "--turn false excludes TURN config"
fi

# Test 9: Unknown option rejected
output=$(run_expect_fail ./up.sh --unknown-flag)
assert_contains "$output" "unknown option" \
    "Reject unknown option"

# Test 10: --studio-url requires argument
output=$(run_expect_fail ./up.sh --studio-url)
assert_contains "$output" "--studio-url requires" \
    "Reject --studio-url without argument"

rm -f /tmp/test.yaml /tmp/test-turn.yaml /tmp/test-noturn.yaml
test_summary
