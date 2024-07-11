#!/usr/bin/env bash
# Runs the test suites with the standalone Luau CLI (no Studio needed).
# Usage: scripts/test-offline.sh [tests/Foo.test.luau ...]   (default: all suites)
# Set LUAU to the luau binary if it isn't on PATH.
set -euo pipefail

cd "$(dirname "$0")/.."
LUAU="${LUAU:-luau}"
# A suite that hangs fails instead of blocking CI
RUNNER=()
if command -v timeout >/dev/null 2>&1; then
	RUNNER=(timeout 120)
fi
BUNDLE="$(mktemp -t rivue-tests-XXXXXX.luau)"
trap 'rm -f "$BUNDLE"' EXIT

if [ "$#" -gt 0 ]; then
	FILES=("$@")
else
	FILES=(tests/*.test.luau tests/offline/*.test.luau)
fi

status=0
for file in "${FILES[@]}"; do
	python3 tests/offline/bundle.py "$file" > "$BUNDLE"
	if output="$(${RUNNER[@]+"${RUNNER[@]}"} "$LUAU" "$BUNDLE" 2>&1)"; then
		printf '%-40s ok\n' "$(basename "$file")"
	else
		printf '%-40s FAILED\n' "$(basename "$file")"
		echo "$output" | grep -E "FAIL|TIMEOUT|THREAD ERROR|error" | head -5
		status=1
	fi
done
exit $status
