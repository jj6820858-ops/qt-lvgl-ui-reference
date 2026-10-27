#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "clang-format..."
find common core domain services infrastructure models backend app gallery tests ui \
     -name '*.cpp' -o -name '*.h' 2>/dev/null | xargs -r clang-format -i

if command -v qmlformat >/dev/null 2>&1; then
    echo "qmlformat..."
    find ui app gallery tests -name '*.qml' | xargs -r qmlformat -i
else
    echo "qmlformat not on PATH — it ships in the Qt bin directory. Skipping."
fi
echo "Done."
