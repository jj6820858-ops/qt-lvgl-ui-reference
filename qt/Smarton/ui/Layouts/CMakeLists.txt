# QML module: SmarTon.Ui.Layouts — arrangement primitives, no content.
qt_add_library(smarton_ui_layouts STATIC)
add_library(SmarTonUi::layouts ALIAS smarton_ui_layouts)

st_add_qml_module(smarton_ui_layouts
    URI     SmarTon.Ui.Layouts
    VERSION 1.0
    NO_PLUGIN
    QML_FILES
        StPage.qml
        StAuthPage.qml
        StScrollView.qml
    IMPORTS
        SmarTon.Ui.Theme
)

target_link_libraries(smarton_ui_layouts
    PUBLIC  SmarTonUi::theme Qt6::Quick
    PRIVATE SmarTon::compile_settings
)
