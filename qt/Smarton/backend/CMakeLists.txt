# App-level C++ singletons QML needs but that are not view models:
# design tokens, branding, environment. Imported by SmarTon.Ui.Theme.
qt_add_library(smarton_backend STATIC)
add_library(SmarTon::backend ALIAS smarton_backend)

target_sources(smarton_backend
    PUBLIC
        FILE_SET HEADERS
        BASE_DIRS include
        FILES
            include/smarton/backend/theme/DesignTokens.h
            include/smarton/backend/theme/Typography.h
            include/smarton/backend/theme/Appearance.h
            include/smarton/backend/Capabilities.h
)

# DEPENDENCIES QtQuick: DesignTokens exposes Q_PROPERTY(QColor ...). Without
# the declared dependency qmllint cannot resolve QColor to the `color` value
# type and reports unresolved-type on every colour property that reads it.
st_add_qml_module(smarton_backend
    URI     SmarTon.Backend
    VERSION 1.0
    DEPENDENCIES
        QtQuick
    SOURCES
        include/smarton/backend/theme/DesignTokens.h
        include/smarton/backend/theme/Typography.h
        include/smarton/backend/theme/Appearance.h
        include/smarton/backend/Capabilities.h
        src/theme/Typography.cpp
        src/theme/Appearance.cpp
)

target_include_directories(smarton_backend PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

target_link_libraries(smarton_backend
    PUBLIC  SmarTon::common SmarTon::services Qt6::Core Qt6::Gui Qt6::Qml
    PRIVATE SmarTon::compile_settings
)

if(ST_HAS_QUICK3D)
    target_compile_definitions(smarton_backend PUBLIC ST_HAS_QUICK3D)
endif()
if(ST_HAS_MQTT)
    target_compile_definitions(smarton_backend PUBLIC ST_HAS_MQTT)
endif()
if(ST_HAS_PARTICLES)
    target_compile_definitions(smarton_backend PUBLIC ST_HAS_PARTICLES)
endif()

set_target_properties(smarton_backend PROPERTIES AUTOUIC OFF AUTORCC OFF)
