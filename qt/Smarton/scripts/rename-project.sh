#!/usr/bin/env bash
# =============================================================================
#  Turn this template into a new project.
#
#  Usage:  ./scripts/rename-project.sh "InstrumentCluster"
#
#  Rewrites four token forms across every file AND renames the include
#  directories that carry the lowercase form:
#
#    AppTemplate    -> InstrumentCluster    project, CMake namespace, QML URI root
#    apptemplate    -> instrumentcluster    targets, C++ namespace, include dirs
#    APPTEMPLATE    -> INSTRUMENTCLUSTER    (none today; reserved)
#    AT_ / At       -> IC_ / Ic             option prefix, QML type prefix
# =============================================================================
set -euo pipefail

if [[ $# -ne 1 ]]; then
    sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi

NEW_PASCAL="$1"
NEW_LOWER="$(printf '%s' "$NEW_PASCAL" | tr '[:upper:]' '[:lower:]')"
NEW_UPPER="$(printf '%s' "$NEW_PASCAL" | tr '[:lower:]' '[:upper:]')"

# Two-letter prefixes derived from the first two capitals, or the first two
# letters if there is only one capital. AppTemplate -> AT; Cluster -> CL.
NEW_CAPS="$(printf '%s' "$NEW_PASCAL" | grep -o '[A-Z]' | tr -d '\n')"
if [[ ${#NEW_CAPS} -ge 2 ]]; then
    NEW_ABBR_UPPER="${NEW_CAPS:0:2}"
else
    NEW_ABBR_UPPER="$(printf '%s' "${NEW_PASCAL:0:2}" | tr '[:lower:]' '[:upper:]')"
fi
NEW_ABBR_PASCAL="${NEW_ABBR_UPPER:0:1}$(printf '%s' "${NEW_ABBR_UPPER:1:1}" | tr '[:upper:]' '[:lower:]')"
NEW_ABBR_LOWER="$(printf '%s' "$NEW_ABBR_UPPER" | tr '[:upper:]' '[:lower:]')"

OLD_PASCAL="AppTemplate"
OLD_LOWER="apptemplate"
OLD_UPPER="APPTEMPLATE"
OLD_ABBR_UPPER="AT"
OLD_ABBR_PASCAL="At"
OLD_ABBR_LOWER="at"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# A build tree here means the copy included artefacts. Renaming would rewrite
# thousands of generated files and leave temp files scattered through them.
# CMakeLists.txt.user pins the ORIGINAL project's build directory. Qt
# Creator then tries to build the new project into the old tree and
# fails with "does not match the source used to generate cache".
for stale in build docs/html docs/latex CMakeLists.txt.user .qtcreator; do
    if [[ -e "$stale" ]]; then
        echo "Refusing to run: '$stale' exists."
        echo
        echo "This copy includes build output. Re-copy source only:"
        echo "  tar -cf - -C <template> --exclude='./build' --exclude='./docs/html' \\"
        echo "        --exclude='./.git' . | tar -xf - -C <destination>"
        echo
        echo "Or remove it here and re-run: rm -rf $stale"
        exit 1
    fi
done

echo "Renaming in $ROOT"
printf '  %-14s -> %s\n' "$OLD_PASCAL"     "$NEW_PASCAL"
printf '  %-14s -> %s\n' "$OLD_LOWER"      "$NEW_LOWER"
printf '  %-14s -> %s\n' "$OLD_UPPER"      "$NEW_UPPER"
printf '  %-14s -> %s   (option prefix AT_)\n'    "$OLD_ABBR_UPPER"  "$NEW_ABBR_UPPER"
printf '  %-14s -> %s   (QML type prefix At*)\n'  "$OLD_ABBR_PASCAL" "$NEW_ABBR_PASCAL"
printf '  %-14s -> %s   (cmake fn at_*)\n'        "$OLD_ABBR_LOWER"  "$NEW_ABBR_LOWER"
echo

# ---- 1. file contents -------------------------------------------------------
# Order matters. The two-letter forms are matched only with a word boundary
# plus an underscore (AT_) or followed by a capital (AtButton), so the letters
# "at" inside ordinary words are never touched.
while IFS= read -r f; do
    case "$f" in
        *.png|*.jpg|*.jpeg|*.ttf|*.otf|*.ico|*.pdf) continue ;;
        ./scripts/rename-project.sh) continue ;;
    esac
    perl -pi -e "
        s/\Q${OLD_PASCAL}\E/${NEW_PASCAL}/g;
        s/\Q${OLD_UPPER}\E/${NEW_UPPER}/g;
        s/\Q${OLD_LOWER}\E/${NEW_LOWER}/g;
        s/\b${OLD_ABBR_UPPER}_/${NEW_ABBR_UPPER}_/g;
        s/\b${OLD_ABBR_PASCAL}(?=[A-Z])/${NEW_ABBR_PASCAL}/g;
        s/\b${OLD_ABBR_LOWER}_/${NEW_ABBR_LOWER}_/g;
    " "$f"
done < <(find . -type f -not -path './.git/*' -not -path './build*/*')

# ---- 2. file names ----------------------------------------------------------
#   AppTemplate*.cmake -> InstrumentCluster*.cmake   (include() must resolve)
#   apptemplate_en.ts  -> instrumentcluster_en.ts
#   At*.qml            -> Ic*.qml
rename_files() {
    local pattern="$1" perl_expr="$2"
    while IFS= read -r f; do
        local base newbase
        base="$(basename "$f")"
        newbase="$(printf '%s' "$base" | perl -pe "$perl_expr")"
        if [[ "$base" != "$newbase" ]]; then
            mv "$f" "$(dirname "$f")/$newbase"
            echo "  renamed file $base -> $newbase"
        fi
    done < <(find . -type f -name "$pattern" -not -path './.git/*' -not -path './build*/*')
}

rename_files "${OLD_PASCAL}*"      "s/^\Q${OLD_PASCAL}\E/${NEW_PASCAL}/"
rename_files "${OLD_LOWER}*"       "s/^\Q${OLD_LOWER}\E/${NEW_LOWER}/"
rename_files "${OLD_ABBR_PASCAL}*" "s/^${OLD_ABBR_PASCAL}(?=[A-Z])/${NEW_ABBR_PASCAL}/"

# ---- 3. directories (include/apptemplate/... -> include/<new>/...) ----------
# Deepest first, so renaming a parent never invalidates a queued child path.
while IFS= read -r d; do
    parent="$(dirname "$d")"
    base="$(basename "$d")"
    if [[ "$base" == "$OLD_LOWER" ]]; then
        mv "$d" "$parent/$NEW_LOWER"
        echo "  renamed dir  $d -> $parent/$NEW_LOWER"
    fi
done < <(find . -depth -type d -name "$OLD_LOWER" -not -path './.git/*' -not -path './build*/*')

echo
echo "Done. Next:"
echo "  1. rm -rf build/"
echo "  2. cmake --preset host-debug && cmake --build --preset host-debug"
echo "  3. ctest --preset host-debug"
echo "  4. Rewrite README.md, docs/architecture.md and docs/adr/ for your domain"
echo "  5. rm scripts/rename-project.sh"
