# Cross-compile toolchain for aarch64 Embedded Linux (Rockchip RK3328 etc.)
#
# This file deliberately leaves compiler selection to the environment script:
#
#   source /opt/poky/4.0.27/environment-setup-armv8a-poky-linux
#   cmake --preset rk3328
#
# The SDK's CC/CXX values carry the target CPU and hardening flags in addition
# to the compiler path. Overriding them here loses those flags and, in older
# versions of this project, selected the unrelated aarch64-linux-gnu toolchain.
set(CMAKE_SYSTEM_NAME      Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

if(NOT DEFINED ENV{SDKTARGETSYSROOT} OR "$ENV{SDKTARGETSYSROOT}" STREQUAL "")
    message(FATAL_ERROR
        "Poky SDK environment is not active. Run ./scripts/build-rk3328.sh "
        "or source /opt/poky/4.0.27/environment-setup-armv8a-poky-linux first.")
endif()

set(TARGET_SYSROOT "$ENV{SDKTARGETSYSROOT}" CACHE PATH "Target sysroot")
# QT_HOST_PATH is the Qt install prefix (which is <native sysroot>/usr), not
# the native sysroot itself. Qt6Config uses this path to locate HostInfo and
# build tools such as moc and qmltyperegistrar.
set(QT_HOST_PATH "$ENV{OECORE_NATIVE_SYSROOT}/usr" CACHE PATH
    "Host Qt tools supplied by the Poky SDK" FORCE)
set(QT_HOST_PATH_CMAKE_DIR "${QT_HOST_PATH}/lib/cmake" CACHE PATH
    "Host Qt CMake packages supplied by the Poky SDK" FORCE)
set(Qt6CoreTools_DIR "${QT_HOST_PATH_CMAKE_DIR}/Qt6CoreTools" CACHE PATH
    "Host Qt Core build tools supplied by the Poky SDK" FORCE)

set(CMAKE_SYSROOT      ${TARGET_SYSROOT})

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
