# The executable. Composition root: this is the ONLY place that knows how the
# layers are wired together. Everything else receives its dependencies.
qt_add_executable(smarton main.cpp)

st_add_qml_module(smarton
    URI     SmarTon.App
    VERSION 1.0
    QML_FILES
        Main.qml
    IMPORTS
        QtQuick.Controls.Basic
        SmarTon.Ui.Components
        SmarTon.Ui.Theme
        SmarTon.Ui.Screens
)

target_compile_definitions(smarton PRIVATE
    ST_VERSION="${PROJECT_VERSION}"
    ST_APPLICATION_NAME="${ST_BRAND_APPLICATION_NAME}"
    ST_DISPLAY_NAME="${ST_BRAND_DISPLAY_NAME}"
    ST_ORGANIZATION="${ST_BRAND_ORGANIZATION}"
    ST_DOMAIN="${ST_BRAND_DOMAIN}"
)

target_link_libraries(smarton PRIVATE
    SmarTon::infrastructure
    SmarTon::services
    SmarTon::models
    SmarTon::backend
    SmarTon::resources
    SmarTonUi::theme
    SmarTonUi::components
    SmarTonUi::screens
    Qt6::Quick
    Qt6::QuickControls2
)

# The application imports these two C++-backed modules. Their Qt 6.2 plugin
# targets are static, so make the dependency explicit as well as scanning QML
# imports below. (Qt 6.2 skips the scanner for a shared Qt build.)
target_link_libraries(smarton PRIVATE
    smarton_backendplugin
    smarton_modelsplugin
)

# Qt 6.2 does not automatically pull static QML plugins into an executable.
# Without this import scan, the resource-embedded module loader looks for a
# shared `smarton_backendplugin` at runtime. The ThinClient SDK builds QML
# modules as static libraries, so register their plugins with the executable.
qt_import_qml_plugins(smarton)

set_target_properties(smarton PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE    TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER "${ST_BRAND_DOMAIN}.${ST_BRAND_APPLICATION_NAME}"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
)

install(TARGETS smarton
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
