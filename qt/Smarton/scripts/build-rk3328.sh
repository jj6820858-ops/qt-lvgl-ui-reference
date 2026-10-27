#!/usr/bin/env bash
# Build SmarTon with the same Poky ARMv8-A SDK used by ThinClient.
set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SDK_ROOT="${SMARTON_SDK_ROOT:-/opt/poky/4.0.27}"
readonly SDK_ENV="${SDK_ROOT}/environment-setup-armv8a-poky-linux"

if [[ ! -r "${SDK_ENV}" ]]; then
    echo "RK3328 build error: SDK environment not found: ${SDK_ENV}" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${SDK_ENV}"
cd "${PROJECT_ROOT}"

# Poky 4.0.27 bundles CMake 3.22, while this project uses CMake preset v6
# (and requires CMake 3.28). Keep the SDK compiler/sysroot environment but
# use the compatible host CMake binary.
readonly CMAKE_BIN="${SMARTON_CMAKE:-/usr/bin/cmake}"
if [[ ! -x "${CMAKE_BIN}" ]]; then
    echo "RK3328 build error: CMake not executable: ${CMAKE_BIN}" >&2
    exit 1
fi

"${CMAKE_BIN}" --preset rk3328 "$@"
"${CMAKE_BIN}" --build --preset rk3328 --parallel "${SMARTON_BUILD_JOBS:-$(nproc)}"
