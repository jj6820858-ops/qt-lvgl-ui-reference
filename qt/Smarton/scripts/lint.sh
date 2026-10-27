#!/usr/bin/env bash
# Runs every gate CI runs, locally.
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD="${1:-build/host-debug}"

echo "== clang-format (check only) =="
find common core domain services infrastructure models backend app gallery tests \
     -name '*.cpp' -o -name '*.h' 2>/dev/null | xargs -r clang-format --dry-run --Werror

echo "== qmllint (all modules) =="
cmake --build "$BUILD" --target all_qmllint

echo "== tests =="
ctest --test-dir "$BUILD" --output-on-failure

# ---------------------------------------------------------------------------
# Unannotated QML functions.
#
# Qt 6.8 warns at RUNTIME - not at lint time - when an unannotated function's
# result is passed to an annotated one: it has to assume void, keeps the value
# anyway, and says so on every single call. A future Qt will drop the value
# instead, at which point the call silently does nothing. qmllint does not
# catch it, so this does.
# ---------------------------------------------------------------------------
echo "==> Checking QML function annotations"
unannotated=$(grep -rn '^[[:space:]]*function [a-zA-Z_]' ui app gallery \
                  --include='*.qml' 2>/dev/null \
              | grep -v '): *[A-Za-z]' | grep -v 'function on[A-Z]' || true)
if [ -n "$unannotated" ]; then
    echo "FAIL: these QML functions need a return type (use ': void' if they return nothing):"
    echo "$unannotated"
    exit 1
fi
echo "    all QML functions annotated"

echo "All gates passed."
