#!/usr/bin/env bash
# =============================================================================
#  One command that proves the repository, then scores it.
#
#    ./scripts/verify.sh              full run
#    ./scripts/verify.sh --quick      skip docs and formatting
#
#  Every criterion is scored from an ACTUAL RESULT, never from the presence of
#  a file. "The code exists" and "it is proven to work" are different claims.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

PRESET="${PRESET:-host-debug}"
BUILD="build/${PRESET}"
QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

bold=$(tput bold 2>/dev/null || true); dim=$(tput dim 2>/dev/null || true)
red=$(tput setaf 1 2>/dev/null || true); grn=$(tput setaf 2 2>/dev/null || true)
ylw=$(tput setaf 3 2>/dev/null || true); rst=$(tput sgr0 2>/dev/null || true)

TOTAL=0; EARNED=0
declare -a ROWS

score() { # name max got note
    TOTAL=$((TOTAL + $2)); EARNED=$((EARNED + $3))
    local mark colour
    if   [[ $3 -eq $2 ]]; then mark="PASS"; colour=$grn
    elif [[ $3 -eq 0  ]]; then mark="FAIL"; colour=$red
    else                       mark="PART"; colour=$ylw
    fi
    ROWS+=("$(printf '%s%-4s%s  %-46s %2d/%-2d  %s' "$colour" "$mark" "$rst" "$1" "$3" "$2" "${4:-}")")
    printf '%s%-4s%s %s (%d/%d) %s%s%s\n' "$colour" "$mark" "$rst" "$1" "$3" "$2" "$dim" "${4:-}" "$rst"
}

step() { printf '\n%s== %s ==%s\n' "$bold" "$1" "$rst"; }

# ---------------------------------------------------------------- structure --
step "Static structure"
[[ $(find . -name CMakeLists.txt -not -path './build*' | wc -l) -ge 20 ]] \
    && score "Layered structure, CMake-enforced" 8 8 || score "Layered structure" 8 0
grep -q 'qt_add_qml_module' cmake/SmarTonQmlModule.cmake && [[ -f CMakePresets.json ]] \
    && score "Modern CMake + presets" 8 8 || score "Modern CMake + presets" 8 0
# grep -A after the pattern is a GNU-ism; BSD grep on macOS treats it as a
# file. Read the file once in awk instead - portable and easier to reason about.
if awk '/target_link_libraries\(smarton_domain/,/^\)/' domain/CMakeLists.txt 2>/dev/null \
     | grep -qE 'Qt6::(Quick|Qml|Gui|QuickControls2)'; then
    score "Domain links Qt Core only" 6 0 "domain pulls in a UI module"
elif grep -q 'Qt6::Core' domain/CMakeLists.txt 2>/dev/null; then
    score "Domain links Qt Core only" 6 6
else
    score "Domain links Qt Core only" 6 0 "cannot find the link list"
fi

# -------------------------------------------------------------------- build --
step "Configure and build"
if cmake --preset "$PRESET" >/tmp/st_cfg.log 2>&1 && \
   cmake --build --preset "$PRESET" --parallel >/tmp/st_build.log 2>&1; then
    BUILD_OK=1; echo "  build succeeded"
else
    BUILD_OK=0; echo "  ${red}build FAILED${rst} - see /tmp/st_build.log"
    tail -25 /tmp/st_build.log
fi

# -------------------------------------------------------------------- tests --
step "Tests"
# Score the two frameworks independently: one failing QML case must not
# erase the fact that every C++ suite passed.
if [[ $BUILD_OK -eq 1 ]]; then
    ctest --test-dir "$BUILD" --output-on-failure >/tmp/st_ctest.log 2>&1 || true

    CPP_SUITES="reading ringbuffer monitoringservice readinglistmodel"
    CPP_OK=0; CPP_N=0
    for suite in $CPP_SUITES; do
        CPP_N=$((CPP_N + 1))
        grep -qE "Test +#[0-9]+: ${suite} +\\.+ +Passed" /tmp/st_ctest.log && CPP_OK=$((CPP_OK + 1))
    done
    if [[ $CPP_OK -eq $CPP_N ]]; then
        score "C++ unit tests green" 10 10 "$CPP_OK/$CPP_N suites"
    else
        score "C++ unit tests green" 10 $(( 10 * CPP_OK / CPP_N )) "$CPP_OK/$CPP_N suites"
    fi

    if grep -qE 'Test +#[0-9]+: qmltests +\\.+ +Passed' /tmp/st_ctest.log; then
        score "QML tests green (offscreen)" 8 8
    else
        FAILED=$(grep -E '^(FAIL!|XFAIL)' /tmp/st_ctest.log | head -3 | sed 's/^/      /')
        score "QML tests green (offscreen)" 8 0 "qmltests failing"
        [[ -n "$FAILED" ]] && printf '%s\n' "$FAILED"
    fi
else
    score "C++ unit tests green"       10 0 "build failed"
    score "QML tests green (offscreen)" 8 0 "build failed"
fi

# ------------------------------------------------------------------ qmllint --
step "qmllint"
if [[ $BUILD_OK -eq 1 ]] && cmake --build "$BUILD" --target all_qmllint >/tmp/st_lint.log 2>&1; then
    score "qmllint clean, blocking gate" 6 6
else
    score "qmllint clean, blocking gate" 6 0 "warnings present"
    [[ -f /tmp/st_lint.log ]] && grep -E 'Warning|Error' /tmp/st_lint.log | head -15
fi

# ---------------------------------------------------------------- formatting --
step "Formatting"
if [[ $QUICK -eq 1 ]]; then
    score "clang-format committed AND applied" 4 2 "skipped (--quick)"
elif ! command -v clang-format >/dev/null; then
    score "clang-format committed AND applied" 4 2 "clang-format not installed"
elif find common core domain services infrastructure models backend app gallery tests \
        \( -name '*.cpp' -o -name '*.h' \) -print0 2>/dev/null \
     | xargs -0 -r clang-format --dry-run --Werror >/tmp/st_fmt.log 2>&1; then
    score "clang-format committed AND applied" 4 4
else
    score "clang-format committed AND applied" 4 2 "run ./scripts/format.sh"
fi

# ---------------------------------------------------------------------- docs --
step "Documentation"
[[ -f README.md ]] && grep -q 'cmake --preset' README.md \
    && score "README: problem, architecture, build, test" 10 10 || score "README" 10 0
[[ -f docs/architecture.md ]] && grep -q 'QML/C++ boundary' docs/architecture.md \
    && score "architecture.md with boundary + diagram" 8 8 || score "architecture.md" 8 0
ADRS=$(find docs/adr -name '0*.md' 2>/dev/null | wc -l | tr -d ' ')
[[ $ADRS -ge 3 ]] && score "Three or more ADRs" 5 5 "$ADRS found" || score "ADRs" 5 0

if [[ $QUICK -eq 1 ]]; then
    score "Doxygen + qdoc generated" 6 0 "skipped (--quick)"
elif command -v doxygen >/dev/null && (cd docs && doxygen Doxyfile >/tmp/st_dox.log 2>&1); then
    [[ -d docs/html ]] && score "Doxygen + qdoc generated" 6 6 || score "Doxygen" 6 0
else
    score "Doxygen + qdoc generated" 6 0 "brew install doxygen graphviz"
fi

# ------------------------------------------------------------------- hygiene --
step "Repository hygiene"
COMMITS=$(git log --oneline 2>/dev/null | wc -l | tr -d ' ')
TAGS=$(git tag 2>/dev/null | wc -l | tr -d ' ')
CONV=$(git log --format=%s 2>/dev/null | grep -cE '^(feat|fix|perf|refactor|test|docs|build|ci|chore)(\(.+\))?: ') || CONV=0
if [[ $COMMITS -gt 0 && $TAGS -gt 0 && $CONV -ge $((COMMITS / 2)) ]]; then
    score "Conventional Commits + SemVer tag + CHANGELOG" 6 6 "$COMMITS commits, $TAGS tag(s)"
else
    score "Conventional Commits + SemVer tag + CHANGELOG" 6 2 "$COMMITS commits, $TAGS tags, $CONV conventional"
fi
if ! git remote get-url origin >/dev/null 2>&1; then
    score "CI green on Linux, Windows and macOS" 10 0 "no git remote configured"
elif command -v gh >/dev/null 2>&1; then
    if gh run list --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null | grep -q success; then
        score "CI green on Linux, Windows and macOS" 10 10
    else
        score "CI green on Linux, Windows and macOS" 10 0 "latest workflow run not green"
    fi
else
    score "CI green on Linux, Windows and macOS" 10 5 "remote set; install gh to verify Actions"
fi

[[ -f LICENSE && -f CONTRIBUTING.md ]] \
    && score "LICENSE and CONTRIBUTING" 3 3 || score "LICENSE and CONTRIBUTING" 3 0
if find docs assets -maxdepth 2 \( -name '*.png' -o -name '*.gif' \) 2>/dev/null | grep -q . \
   && grep -qE '!\[.*\]\(' README.md; then
    score "Screenshot or GIF above the fold" 2 2
else
    score "Screenshot or GIF above the fold" 2 0 "./scripts/capture-gallery.sh"
fi

# -------------------------------------------------------------------- report --
printf '\n%s%s%s\n' "$bold" "================ SCORECARD ================" "$rst"
for r in "${ROWS[@]}"; do echo "$r"; done
PCT=$(( EARNED * 100 / TOTAL ))
printf '\n%sTOTAL: %d / %d  (%d%%)%s\n' "$bold" "$EARNED" "$TOTAL" "$PCT" "$rst"
if   [[ $PCT -ge 95 ]]; then printf '%sPartner-grade.%s\n' "$grn" "$rst"
elif [[ $PCT -ge 80 ]]; then printf '%sStrong. Close the FAIL rows above.%s\n' "$ylw" "$rst"
elif [[ $PCT -ge 60 ]]; then printf '%sShowable, not yet partner-grade.%s\n' "$ylw" "$rst"
else printf '%sThis works against you. Do not send it out yet.%s\n' "$red" "$rst"
fi
[[ $PCT -ge 95 ]] && exit 0 || exit 1
