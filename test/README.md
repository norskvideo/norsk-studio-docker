# Test Suite

Automated tests for norsk-studio-docker unification.

## Running Tests

```bash
# Run all tests
./test/run-all.sh

# Run specific test suite
./test/test-up-sh-validation.sh
./test/test-up-sh-modes.sh
```

## Test Coverage

**test-up-sh-validation.sh** (10 tests)
- Simple vs advanced mode mutual exclusion
- URL pair requirements (--public-url + --studio-url)
- Missing argument validation
- Help text

**test-up-sh-modes.sh** (6 tests)
- --pull-only flag behavior
- Advanced mode with both URLs
- Deprecation warnings for env vars

## Writing New Tests

Use helper functions from `common.sh`:

```bash
source test/common.sh

# Test that output contains expected string
assert_contains "$output" "expected text" "test description"

# Test exit code
assert_exit_code 0 $? "command should succeed"

# Manual pass/fail
if [[ condition ]]; then
    pass "test description"
else
    fail "test description" "expected" "got"
fi

# Print summary at end
test_summary
```

## CI Integration

Tests use `--merge` to generate docker-compose config without starting containers.
No license file or running docker daemon required.
Exit code 0 = pass, non-zero = fail.

## What's NOT Tested

- Actual container startup (requires license, slow)
- Network connectivity
- Hardware detection (requires actual hardware)
- systemd service integration (needs deployment environment)
