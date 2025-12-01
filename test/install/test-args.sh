#!/usr/bin/env bash

# Test bootstrap.sh argument parsing
# Does not execute installation, only validates parsing logic

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BOOTSTRAP="$REPO_ROOT/scripts/bootstrap.sh"

echo "=== Testing bootstrap.sh argument parsing ==="

# Test 1: Help flag
echo "Test 1: --help flag"
if "$BOOTSTRAP" --help | grep -q "Usage:"; then
  echo "✓ Help output works"
else
  echo "✗ Help output failed"
  exit 1
fi

# Test 2: Missing required args
echo "Test 2: Missing required arguments"
if ("$BOOTSTRAP" --hardware=none 2>&1 || true) | grep -q "Error: --license is required"; then
  echo "✓ License validation works"
else
  echo "✗ License validation failed"
  exit 1
fi

# Test 3: Invalid hardware type
echo "Test 3: Invalid hardware type"
if ("$BOOTSTRAP" --hardware=invalid --license=test --password=test 2>&1 || true) | grep -q "Error: --hardware must be one of"; then
  echo "✓ Hardware validation works"
else
  echo "✗ Hardware validation failed"
  exit 1
fi

# Test 4: Syntax check
echo "Test 4: Bash syntax check"
if bash -n "$BOOTSTRAP"; then
  echo "✓ Syntax valid"
else
  echo "✗ Syntax error"
  exit 1
fi

# Test 5: Check all lib modules exist
echo "Test 5: Check lib modules"
for module in 00-common.sh 10-secrets.sh 20-platform.sh 30-containers.sh; do
  if [[ -f "$REPO_ROOT/scripts/lib/$module" ]]; then
    echo "✓ $module exists"
  else
    echo "✗ $module missing"
    exit 1
  fi
done

# Test 6: Check hardware profiles exist
echo "Test 6: Check hardware profiles"
for profile in none.sh quadra.sh nvidia.sh; do
  if [[ -f "$REPO_ROOT/scripts/hardware/$profile" ]]; then
    echo "✓ $profile exists"
  else
    echo "✗ $profile missing"
    exit 1
  fi
done

# Test 7: Check platform scripts exist
echo "Test 7: Check platform scripts"
for platform in linode.sh google.sh oracle.sh local.sh; do
  if [[ -f "$REPO_ROOT/scripts/platforms/$platform" ]]; then
    echo "✓ $platform exists"
  else
    echo "✗ $platform missing"
    exit 1
  fi
done

echo ""
echo "=== All argument parsing tests passed ==="
