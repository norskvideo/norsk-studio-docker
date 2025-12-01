# Bootstrap Script Tests

Test framework for scripts/bootstrap.sh

## Running Tests

```bash
# Test basic argument parsing
./test/install/test-args.sh

# Test in Docker container (requires Docker)
./test/install/test-docker.sh
```

## Test Structure

- `test-args.sh` - Validates argument parsing without execution
- `test-docker.sh` - Runs bootstrap in Ubuntu container
- `Dockerfile.test` - Test container definition
- `mock-hardware/` - Hardware detection mocks for testing
