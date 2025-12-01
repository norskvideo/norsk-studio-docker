#!/usr/bin/env bash
# Common test utilities

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Run command that should fail, capturing output and verifying non-zero exit
run_expect_fail() {
    set +e
    local output
    output=$("$@" 2>&1)
    local code=$?
    set -e

    if [[ $code -eq 0 ]]; then
        echo "ERROR: Command succeeded but was expected to fail: $*" >&2
        return 1
    fi

    echo "$output"
    return 0
}

pass() {
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $1"
    if [[ -n "${2:-}" ]]; then
        echo "  Expected: $2"
    fi
    if [[ -n "${3:-}" ]]; then
        echo "  Got: $3"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"

    ((TESTS_RUN++))
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$test_name"
        return 0
    else
        fail "$test_name" "contains '$needle'" "didn't find it"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    ((TESTS_RUN++))
    if [[ "$expected" -eq "$actual" ]]; then
        pass "$test_name"
        return 0
    else
        fail "$test_name" "exit code $expected" "exit code $actual"
        return 1
    fi
}

test_summary() {
    echo ""
    echo "========================================"
    echo "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Failed: $TESTS_FAILED${NC}"
        return 1
    else
        echo "All tests passed!"
        return 0
    fi
}
