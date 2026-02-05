#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")/.."
source test/common.sh
set +e

echo "Testing plugin workflow..."
echo ""

# Save original config
cp config/default.yaml config/default.yaml.test-backup

cleanup() {
    mv config/default.yaml.test-backup config/default.yaml 2>/dev/null || true
    rm -rf plugins/test-plugin 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: --list-plugins works
output=$(./manage.sh --list-plugins)
assert_contains "$output" "Enabled libraries" \
    "--list-plugins shows enabled libraries"

# Test 2: --enable-alpha adds alpha to config
./manage.sh --enable-alpha >/dev/null
output=$(grep "norsk-studio-alpha" config/default.yaml)
((TESTS_RUN++))
if [[ -n "$output" ]]; then
    pass "--enable-alpha adds alpha to config"
else
    fail "--enable-alpha adds alpha to config"
fi

# Test 3: --enable-alpha is idempotent
./manage.sh --enable-alpha >/dev/null
./manage.sh --enable-alpha >/dev/null
count=$(grep -c "norsk-studio-alpha" config/default.yaml)
((TESTS_RUN++))
if [[ "$count" -eq 1 ]]; then
    pass "--enable-alpha is idempotent (no duplicates)"
else
    fail "--enable-alpha is idempotent" "1 occurrence" "$count occurrences"
fi

# Test 4: --disable-alpha removes alpha from config
./manage.sh --disable-alpha >/dev/null
((TESTS_RUN++))
if ! grep -q "norsk-studio-alpha" config/default.yaml; then
    pass "--disable-alpha removes alpha from config"
else
    fail "--disable-alpha removes alpha from config"
fi

# Test 5: --disable-alpha is idempotent
output=$(./manage.sh --disable-alpha 2>&1)
assert_contains "$output" "Not enabled" \
    "--disable-alpha is idempotent (no error if not present)"

# Test 6: --enable-beta works
./manage.sh --enable-beta >/dev/null
((TESTS_RUN++))
if grep -q "norsk-studio-beta" config/default.yaml; then
    pass "--enable-beta adds beta to config"
else
    fail "--enable-beta adds beta to config"
fi

# Test 7: --disable-beta works
./manage.sh --disable-beta >/dev/null
((TESTS_RUN++))
if ! grep -q "norsk-studio-beta" config/default.yaml; then
    pass "--disable-beta removes beta from config"
else
    fail "--disable-beta removes beta from config"
fi

# Test 8: --enable-plugin works with custom name
./manage.sh --enable-plugin my-custom-plugin >/dev/null
((TESTS_RUN++))
if grep -q "my-custom-plugin" config/default.yaml; then
    pass "--enable-plugin adds custom plugin to config"
else
    fail "--enable-plugin adds custom plugin to config"
fi

# Test 9: --disable-plugin works
./manage.sh --disable-plugin my-custom-plugin >/dev/null
((TESTS_RUN++))
if ! grep -q "my-custom-plugin" config/default.yaml; then
    pass "--disable-plugin removes custom plugin from config"
else
    fail "--disable-plugin removes custom plugin from config"
fi

# Test 10: --enable-plugin requires argument
output=$(run_expect_fail ./manage.sh --enable-plugin)
assert_contains "$output" "requires a plugin name" \
    "--enable-plugin requires argument"

# Test 11: --disable-plugin requires argument
output=$(run_expect_fail ./manage.sh --disable-plugin)
assert_contains "$output" "requires a plugin name" \
    "--disable-plugin requires argument"

# Test 12: --list-plugins shows local plugins
mkdir -p plugins/test-plugin
echo '{"name": "test-plugin", "version": "1.0.0"}' > plugins/test-plugin/package.json
output=$(./manage.sh --list-plugins)
assert_contains "$output" "test-plugin" \
    "--list-plugins shows local plugins"

# Test 13: --list-plugins shows enabled status for local plugins
./manage.sh --enable-plugin test-plugin >/dev/null
output=$(./manage.sh --list-plugins)
assert_contains "$output" "test-plugin (enabled)" \
    "--list-plugins shows enabled status for local plugins"

# Test 14: Config file remains valid YAML after modifications
# Re-enable some things and check yq can still parse it
./manage.sh --enable-alpha >/dev/null
./manage.sh --enable-beta >/dev/null
./manage.sh --enable-plugin another-plugin >/dev/null
output=$(./manage.sh --list-plugins 2>&1)
((TESTS_RUN++))
if [[ $? -eq 0 ]] && [[ "$output" == *"Enabled libraries"* ]]; then
    pass "Config file remains valid after multiple modifications"
else
    fail "Config file remains valid after multiple modifications"
fi

# Test 15: --build-image requires plugins or confirmation (can't fully test without docker)
# Just check the help mentions it
output=$(./manage.sh --help)
assert_contains "$output" "build-image" \
    "--help mentions --build-image"

# Test 16: --install-plugin requires argument
output=$(run_expect_fail ./manage.sh --install-plugin)
assert_contains "$output" "requires a package name" \
    "--install-plugin requires argument"

# Test 17: --help mentions --install-plugin
output=$(./manage.sh --help)
assert_contains "$output" "install-plugin" \
    "--help mentions --install-plugin"

test_summary
