#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")/.."
source test/common.sh

# Disable set -e for test execution since we expect failures
set +e

echo "Testing up.sh flag validation..."
echo ""

# Test 1: --host-ip cannot be used with --public-url
output=$(run_expect_fail ./up.sh --host-ip 1.2.3.4 --public-url "http://test")
assert_contains "$output" "Cannot use --host-ip with advanced" \
    "Reject --host-ip + --public-url"

# Test 2: --host-ip cannot be used with --studio-url
output=$(run_expect_fail ./up.sh --host-ip 1.2.3.4 --studio-url "http://test")
assert_contains "$output" "Cannot use --host-ip with advanced" \
    "Reject --host-ip + --studio-url"

# Test 3: --host-ip cannot be used with --ice-servers
output=$(run_expect_fail ./up.sh --host-ip 1.2.3.4 --ice-servers '[]')
assert_contains "$output" "Cannot use --host-ip with advanced" \
    "Reject --host-ip + --ice-servers"

# Test 4: --public-url requires --studio-url
output=$(run_expect_fail ./up.sh --public-url "http://test")
assert_contains "$output" "--public-url requires --studio-url" \
    "Require --studio-url with --public-url"

# Test 5: --studio-url requires --public-url
output=$(run_expect_fail ./up.sh --studio-url "http://test")
assert_contains "$output" "--studio-url requires --public-url" \
    "Require --public-url with --studio-url"

# Test 6: --help should work
output=$(./up.sh --help)
assert_contains "$output" "Simple Mode" \
    "Help text shows Simple Mode"
assert_contains "$output" "Advanced Mode" \
    "Help text shows Advanced Mode"

# Test 7: Missing argument for --host-ip
output=$(run_expect_fail ./up.sh --host-ip)
assert_contains "$output" "--host-ip requires an IP address" \
    "Reject --host-ip without argument"

# Test 8: Missing argument for --public-url
output=$(run_expect_fail ./up.sh --public-url)
assert_contains "$output" "--public-url requires a URL" \
    "Reject --public-url without argument"

# Test 9: Missing argument for --ice-servers
output=$(run_expect_fail ./up.sh --ice-servers)
assert_contains "$output" "--ice-servers requires a JSON array" \
    "Reject --ice-servers without argument"

test_summary
