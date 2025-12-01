#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")/.."
source test/common.sh

# Disable set -e for test execution since we expect some failures
set +e

echo "Testing up.sh simple vs advanced modes..."
echo ""

# Test 1: --pull-only and --merge are mutually exclusive
output=$(run_expect_fail ./up.sh --pull-only --merge /tmp/test-pull.yaml)
assert_contains "$output" "--pull-only and --merge are mutually exclusive" \
    "Reject --pull-only + --merge"

# Test 2: Advanced mode with both URLs works
output=$(./up.sh --public-url "https://example.com/norsk" \
                 --studio-url "https://example.com/studio" \
                 --merge /tmp/test-advanced.yaml)
# Should not error
if [[ "$output" == *"Error:"* ]]; then
    fail "Advanced mode with both URLs" "no error" "got error"
    ((TESTS_RUN++))
else
    pass "Advanced mode with both URLs"
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
fi

# Test 3: Deprecation warning for HOST_IP env var
output=$(HOST_IP=1.2.3.4 ./up.sh --merge /tmp/test-deprecated.yaml 2>&1)
assert_contains "$output" "HOST_IP env var is deprecated, use --host-ip flag" \
    "Warn on deprecated HOST_IP env var"

# Test 4: Deprecation warning for PUBLIC_URL_PREFIX env var
output=$(PUBLIC_URL_PREFIX="http://test" ./up.sh --merge /tmp/test-deprecated2.yaml 2>&1)
assert_contains "$output" "PUBLIC_URL_PREFIX env var is deprecated, use --public-url flag" \
    "Warn on deprecated PUBLIC_URL_PREFIX env var"

# Test 5: Deprecation warning for GLOBAL_ICE_SERVERS env var
output=$(GLOBAL_ICE_SERVERS='[]' ./up.sh --merge /tmp/test-deprecated3.yaml 2>&1)
assert_contains "$output" "GLOBAL_ICE_SERVERS env var is deprecated, use --ice-servers flag" \
    "Warn on deprecated GLOBAL_ICE_SERVERS env var"

# Cleanup
rm -f /tmp/test-*.yaml

test_summary
