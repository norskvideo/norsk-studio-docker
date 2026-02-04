#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")/.."

UNIT_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --unit-only)
            UNIT_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "========================================"
echo "Running Norsk Studio Docker Tests"
echo "========================================"
echo ""

failed=0

# Run bash unit tests
echo "=== Unit Tests (Bash) ==="
echo ""
for test_file in test/test-*.sh; do
    echo "Running $(basename "$test_file")..."
    if bash "$test_file"; then
        echo ""
    else
        failed=1
        echo ""
    fi
done

# Run integration tests unless --unit-only
if [[ "$UNIT_ONLY" != "true" ]]; then
    echo "=== Integration Tests (Mocha) ==="
    echo ""

    # Install dependencies if needed
    if [[ ! -d test/node_modules ]]; then
        echo "Installing test dependencies..."
        npm --prefix test install
        echo ""
    fi

    # Run mocha tests
    if npx --prefix test mocha 'test/integration/**/*.test.js' --timeout 180000; then
        echo ""
    else
        failed=1
        echo ""
    fi
fi

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
