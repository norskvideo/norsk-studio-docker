#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")/.."

echo "========================================"
echo "Running Norsk Studio Docker Tests"
echo "========================================"
echo ""

failed=0

# Run each test suite
for test_file in test/test-*.sh; do
    echo "Running $(basename "$test_file")..."
    if bash "$test_file"; then
        echo ""
    else
        failed=1
        echo ""
    fi
done

if [[ $failed -eq 1 ]]; then
    echo "========================================"
    echo "SOME TESTS FAILED"
    echo "========================================"
    exit 1
else
    echo "========================================"
    echo "ALL TEST SUITES PASSED"
    echo "========================================"
    exit 0
fi
