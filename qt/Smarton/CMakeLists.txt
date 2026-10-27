# =============================================================================
#  SmarTon — reference Qt 6 application, layered architecture
#
#  Rename for a new project:  ./scripts/rename-project.sh "InstrumentCluster"
#
#  Layer order below is also the dependency order. Nothing links upward.
# =============================================================================
cmake_minimum_required(VERSION 3.28)

# --- brand ------------------------------------------------------------------
# Everything user-visible is a cache variable, so a downstream build can
# rebrand without touching source.
set(ST_BRAND_APPLICATION_NAME "SmarTon"  CACHE STRING "Executable and settings name")
set(ST_BRAND_DISPLAY_NAME     "SmarTon"  CACHE STRING "Human-readable display name")
set(ST_BRAND_ORGANIZATION     "SmarTon"  CACHE STRING "Qt organization name")
set(ST_BRAND_DOMAIN           "smarton.local" CACHE STRING "Organization domain / bundle id prefix")
set(ST_BRAND_TAGLINE          "Easy living with your smart home" CACHE STRING "Short tagline")

project(SmarTon
    VERSION     0.1.0
    DESCRIPTION "${ST_BRAND_DISPLAY_NAME} — smart-home control for a 1024x600 panel"
    LANGUAGES   CXX
)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR "In-source builds are not supported. Use: cmake -S . -B build/host-debug")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(GNUInstallDirs)
include(CTest)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# --- options ----------------------------------------------------------------
option(ST_BUILD_TESTS        "Build tests"                              ${BUILD_TESTING})
option(ST_BUILD_GALLERY      "Build the QML component gallery"          ON)
option(ST_BUILD_TRANSLATIONS "Build Qt Linguist translations"           ON)
option(ST_ENABLE_QMLLINT     "Create QML lint targets"                  ON)
option(ST_WARNINGS_AS_ERRORS "Treat compiler warnings as errors"        OFF)

# Sql     : SQLite account storage.
# Network : QPasswordDigestor (PBKDF2) lives in Qt Network, not Qt Core.
find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2
                                         QuickDialogs2 Sql Network)

# ---------------------------------------------------------------------------
#  Quick3D: OPTIONAL, on purpose.
#
#  The 3D map view is the nicest thing on the Rooms screen and it is also the
#  one feature with a hard dependency the rest of the app does not have. Qt
#  Quick 3D needs the RHI with a working GPU backend; a minimal Qt build, a
#  headless CI container and some embedded images ship without the module at
#  all. Making it REQUIRED would mean an application that will not build for
#  someone who does not want a 3D floor plan.
#
#  So it is detected, and the 2D plan stays as the fallback rather than as
#  dead code. Capabilities::mapView3D reports which one is available, and the
#  Rooms screen offers the toggle only when there is something to toggle to.
# ---------------------------------------------------------------------------
find_package(Qt6 6.2 QUIET COMPONENTS Quick3D)
if(Qt6Quick3D_FOUND)
    set(ST_HAS_QUICK3D ON)
    message(STATUS "Qt Quick 3D found - 3D map view enabled")
else()
    set(ST_HAS_QUICK3D OFF)
    message(STATUS "Qt Quick 3D not found - map view falls back to the 2D plan")
endif()

# Same treatment for Qt Quick Particles, and for the same reason: it ships with
# qtdeclarative but is not present in every packaging, and a missing QML module
# fails every component that imports it. The dust layer behind the glass theme
# is decoration - it must never be able to take a screen down.
find_package(Qt6 6.2 QUIET COMPONENTS QuickParticles)
if(Qt6QuickParticles_FOUND)
    set(ST_HAS_PARTICLES ON)
    message(STATUS "Qt Quick Particles found - backdrop dust enabled")
else()
    set(ST_HAS_PARTICLES OFF)
    message(STATUS "Qt Quick Particles not found - backdrop runs without dust")
endif()

# ---------------------------------------------------------------------------
#  Qt MQTT: OPTIONAL, and for a third reason again.
#
#  Quick3D is optional because a GPU-less build cannot run it; Particles
#  because some packagings omit it. Qt MQTT is optional because it is a
#  separate add-on module that a default Qt install simply does not include -
#  and the transport it enables is not the default one. A build without it has
#  no MQTT transport, says so if one is asked for, and is otherwise identical.
#
#  See ADR-0019 for why MQTT is the first real transport and ADR-0018 for
#  where Matter plugs into the same seam afterwards.
# ---------------------------------------------------------------------------
find_package(Qt6 6.2 QUIET COMPONENTS Mqtt)
if(Qt6Mqtt_FOUND)
    set(ST_HAS_MQTT ON)
    message(STATUS "Qt MQTT found - the MQTT transport is available")
else()
    set(ST_HAS_MQTT OFF)
    message(STATUS "Qt MQTT not found - only the loopback transport is built")
endif()

if(ST_BUILD_TESTS)
    find_package(Qt6 6.2 REQUIRED COMPONENTS Test QuickTest)
endif()

# qt_add_translations() lives in the LinguistTools package. Optional, because
# a minimal or cross-compiled Qt install often ships without the host tools —
# and a missing translator should not stop the application from building.
if(ST_BUILD_TRANSLATIONS)
    find_package(Qt6 6.2 QUIET COMPONENTS LinguistTools)
    if(NOT Qt6LinguistTools_FOUND)
        message(STATUS "Qt Linguist tools not found - translations disabled")
        set(ST_BUILD_TRANSLATIONS OFF)
    endif()
endif()

# QTP0004 was introduced after the Qt 6.2 runtime on the ThinClient image.
# Use it where available; the explicit module declarations below keep the
# older Qt tooling deterministic as well.
if(COMMAND qt_policy)
    qt_policy(SET QTP0004 NEW)
endif()
if(COMMAND qt_standard_project_setup)
    qt_standard_project_setup(REQUIRES 6.2)
else()
    # Qt 6.2 on the deployed ThinClient image predates this convenience API.
    # These are the setup behaviours SmarTon relies on.
    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)
endif()

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

# Generated QML modules are mirrored into one import tree so Qt Creator, qmlls
# and qmllint can resolve SmarTon.* without running the app.
set(ST_QML_IMPORT_ROOT "${CMAKE_BINARY_DIR}/qml" CACHE INTERNAL "Generated QML import tree")
set(QT_QML_OUTPUT_DIRECTORY "${ST_QML_IMPORT_ROOT}")
list(APPEND QML_IMPORT_PATH "${ST_QML_IMPORT_ROOT}")
list(REMOVE_DUPLICATES QML_IMPORT_PATH)
set(QML_IMPORT_PATH "${QML_IMPORT_PATH}" CACHE STRING "QML import paths for IDE tooling" FORCE)

include(SmarTonCompileSettings)
include(SmarTonQmlModule)
include(SmarTonDeveloperTargets)

# --- layers, in dependency order --------------------------------------------
add_subdirectory(common)          # vocabulary types, no dependencies
add_subdirectory(core)            # framework primitives (ring buffer, etc.)
add_subdirectory(domain)          # entities and value objects
add_subdirectory(services)        # domain orchestration
add_subdirectory(infrastructure)  # transports, simulators, persistence
add_subdirectory(models)          # QML-facing view models  -> SmarTon.Models
add_subdirectory(backend)         # app-level C++ for QML   -> SmarTon.Backend
add_subdirectory(ui)              # QML submodules          -> SmarTon.Ui.*
add_subdirectory(resources)
add_subdirectory(app)

if(ST_BUILD_GALLERY)
    add_subdirectory(gallery)
endif()
if(ST_BUILD_TRANSLATIONS)
    add_subdirectory(translations)
endif()
if(ST_BUILD_TESTS)
    add_subdirectory(tests)
endif()

st_add_developer_targets()

message(STATUS "")
message(STATUS "${ST_BRAND_DISPLAY_NAME} ${PROJECT_VERSION}")
message(STATUS "  Qt              : ${Qt6_VERSION}")
message(STATUS "  QML import root : ${ST_QML_IMPORT_ROOT}")
message(STATUS "  Gallery         : ${ST_BUILD_GALLERY}")
message(STATUS "  Translations    : ${ST_BUILD_TRANSLATIONS}")
message(STATUS "  Tests           : ${ST_BUILD_TESTS}")
message(STATUS "")
