#!/usr/bin/env bash

# Test bootstrap.sh in Docker container
# Validates script runs in clean Ubuntu environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Building test container ==="
docker build -t norsk-bootstrap-test -f "$SCRIPT_DIR/Dockerfile.test" "$REPO_ROOT"

echo ""
echo "=== Running bootstrap validation tests ==="

# Test 1: Help command
echo "Test 1: Help command in container"
if docker run --rm norsk-bootstrap-test /test/scripts/bootstrap.sh --help | grep -q "Usage:"; then
  echo "✓ Help works in container"
else
  echo "✗ Help failed in container"
  exit 1
fi

# Test 2: Argument validation
echo "Test 2: Argument validation in container"
if docker run --rm norsk-bootstrap-test /test/scripts/bootstrap.sh --hardware=none 2>&1 | grep -q "Error: --license is required"; then
  echo "✓ Validation works in container"
else
  echo "✗ Validation failed in container"
  exit 1
fi

# Test 3: Module loading (dry-run style check)
echo "Test 3: Module loading check"
docker run --rm norsk-bootstrap-test bash -c '
  for module in /test/scripts/lib/*.sh; do
    if bash -n "$module"; then
      echo "✓ $(basename $module) syntax valid"
    else
      echo "✗ $(basename $module) syntax error"
      exit 1
    fi
  done
'

echo ""
echo "=== Docker tests passed ==="
echo "Note: Full installation test requires root and would install packages"
echo "To test full installation, deploy to actual cloud instance"
