# View models and list models. THIS IS THE QML/C++ BOUNDARY.
#
# Sources are registered through the QML module so QML_ELEMENT types in these
# headers become SmarTon.Models types.
#
# qmltyperegistrar emits `#include <ReadingListModel.h>` — the BASENAME, not
# the path listed below — guarded by __has_include. With this nested layout the
# basename is not on the include path, so st_add_qml_module() automatically
# calls st_add_header_dirs_for_registrar() to add each leaf header directory
# PRIVATE. See cmake/SmarTonQmlModule.cmake and docs/architecture.md.
qt_add_library(smarton_models STATIC)
add_library(SmarTon::models ALIAS smarton_models)

target_sources(smarton_models
    PUBLIC
        FILE_SET HEADERS
        BASE_DIRS include
        FILES
            include/smarton/models/ReadingListModel.h
            include/smarton/models/ActivityListModel.h
            include/smarton/models/DashboardViewModel.h
            include/smarton/models/AuthViewModel.h
            include/smarton/models/HomeListModels.h
            include/smarton/models/HomeViewModel.h
)

st_add_qml_module(smarton_models
    URI     SmarTon.Models
    VERSION 1.0
    SOURCES
        src/ReadingListModel.cpp
        src/ActivityListModel.cpp
        src/DashboardViewModel.cpp
        src/AuthViewModel.cpp
        src/HomeListModels.cpp
        src/HomeViewModel.cpp
)

target_include_directories(smarton_models PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

target_link_libraries(smarton_models
    PUBLIC
        SmarTon::services
        SmarTon::infrastructure
        SmarTon::common
        Qt6::Core
        Qt6::Qml
    PRIVATE
        SmarTon::compile_settings
)

set_target_properties(smarton_models PROPERTIES AUTOUIC OFF AUTORCC OFF)
