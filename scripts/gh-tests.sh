#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")/.."

# Ensure output files exist even if tests fail
touch unit-results.json
touch integration-results.json

# Run unit tests and capture results
echo "Running unit tests..."
UNIT_EXIT=0
./test/run-all.sh --unit-only 2>&1 | tee unit-output.txt || UNIT_EXIT=$?

# Parse unit test results from output (strip ANSI codes first)
# Format: Tests run: N, Passed: M
UNIT_OUTPUT_CLEAN=$(cat unit-output.txt | sed 's/\x1b\[[0-9;]*m//g')
UNIT_TOTAL=$(echo "$UNIT_OUTPUT_CLEAN" | grep -o 'Tests run: [0-9]*' | sed 's/Tests run: //' | paste -sd+ - | bc 2>/dev/null || echo "0")
UNIT_PASSED=$(echo "$UNIT_OUTPUT_CLEAN" | grep -o 'Passed: [0-9]*' | sed 's/Passed: //' | paste -sd+ - | bc 2>/dev/null || echo "0")
# Handle edge case where passed count might exceed total due to test output quirks
if [[ $UNIT_PASSED -gt $UNIT_TOTAL ]]; then
  UNIT_TOTAL=$UNIT_PASSED
fi
UNIT_FAILED=$((UNIT_TOTAL - UNIT_PASSED))

# Create unit results JSON
jq -n \
  --argjson passes "$UNIT_PASSED" \
  --argjson failures "$UNIT_FAILED" \
  --argjson total "$UNIT_TOTAL" \
  '{stats: {passes: $passes, failures: $failures, total: $total}, failures: []}' > unit-results.json

# Run integration tests with JSON reporter
echo "Running integration tests..."
INTEGRATION_EXIT=0
cd test
npm run test:integration:json || INTEGRATION_EXIT=$?
cd ..

# If integration results file is empty or missing, create minimal JSON
if [[ ! -s test/integration-results.json ]]; then
  echo '{"stats": {"passes": 0, "failures": 0}, "failures": []}' > test/integration-results.json
fi
cp test/integration-results.json integration-results.json

# Generate Discord webhook payload
cat unit-results.json integration-results.json | jq -s \
  --arg GITHUB_REF "${GITHUB_REF:-local}" \
  --arg GITHUB_RUN_ID "${GITHUB_RUN_ID:-0}" \
  --arg GITHUB_REPOSITORY "${GITHUB_REPOSITORY:-norskvideo/norsk-studio-docker}" \
'{
  "content": "",
  "avatar_url": "https://i.imgur.com/HzrYPqf.png",
  "username": "Docker CI",
  "embeds": [
    {
      "title": "",
      "color": (if .[0].stats.failures == 0 then 5763719 else 15548997 end),
      "description": (
        "[norsk-studio-docker/" + $GITHUB_REF + "](https://github.com/" + $GITHUB_REPOSITORY + "/actions/runs/" + $GITHUB_RUN_ID + ")"
        + "\r\n"
        + "**Unit Tests:** "
        + (.[0].stats.passes | tostring) + " passed"
        + (if .[0].stats.failures > 0 then ", " + (.[0].stats.failures | tostring) + " failed" else "" end)
      )
    },
    {
      "title": "",
      "color": (if .[1].stats.failures == 0 then 5763719 else 15548997 end),
      "description": (
        "**Integration Tests:** "
        + (.[1].stats.passes | tostring) + " passed"
        + (if .[1].stats.failures > 0 then
            ", " + (.[1].stats.failures | tostring) + " failed"
            + "\r\n**Failed:** \r\n- " + ([.[1].failures[].fullTitle] | join("\r\n- "))
          else "" end)
      )
    }
  ]
}' > discord.json

# Generate GitHub step summary
cat unit-results.json integration-results.json | jq -r -s \
  --arg GITHUB_REF "${GITHUB_REF:-local}" \
  --arg GITHUB_RUN_ID "${GITHUB_RUN_ID:-0}" \
  --arg GITHUB_REPOSITORY "${GITHUB_REPOSITORY:-norskvideo/norsk-studio-docker}" \
'"## Test Results\n\n" +
"| Suite | Passed | Failed |\n" +
"|-------|--------|--------|\n" +
"| Unit Tests | " + (.[0].stats.passes | tostring) + " | " + (.[0].stats.failures | tostring) + " |\n" +
"| Integration Tests | " + (.[1].stats.passes | tostring) + " | " + (.[1].stats.failures | tostring) + " |\n" +
"\n" +
(if (.[0].stats.failures > 0 or .[1].stats.failures > 0) then
  "### Failed Tests\n\n" +
  (if .[1].stats.failures > 0 then
    ([.[1].failures[].fullTitle] | map("- " + .) | join("\n")) + "\n"
  else "" end)
else
  "All tests passed! :white_check_mark:\n"
end)' > gh-summary.md

echo "=== Discord payload ==="
cat discord.json

echo ""
echo "=== GitHub summary ==="
cat gh-summary.md

# Write to GitHub step summary if available
if [[ -n "$GITHUB_STEP_SUMMARY" ]]; then
  cat gh-summary.md >> "$GITHUB_STEP_SUMMARY"
fi

# Clean up
rm -f unit-output.txt unit-results.json integration-results.json test/integration-results.json

# Exit with failure if any tests failed
if [[ $UNIT_EXIT -ne 0 || $INTEGRATION_EXIT -ne 0 ]]; then
  exit 1
fi
