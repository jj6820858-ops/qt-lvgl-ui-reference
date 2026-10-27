# QML module: SmarTon.Ui.Theme
qt_add_library(smarton_ui_theme STATIC)
add_library(SmarTonUi::theme ALIAS smarton_ui_theme)

set_source_files_properties(Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

st_add_qml_module(smarton_ui_theme
    URI     SmarTon.Ui.Theme
    VERSION 1.0
    NO_PLUGIN
    QML_FILES
        Theme.qml
    IMPORTS
        SmarTon.Backend
    DEPENDENCIES
        QtQuick
)

target_link_libraries(smarton_ui_theme
    PUBLIC  SmarTon::backend Qt6::Quick
    PRIVATE SmarTon::compile_settings
)
