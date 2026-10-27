# QML module: SmarTon.Ui.Navigation — moving between screens.
set_source_files_properties(Routes.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_library(smarton_ui_navigation STATIC)
add_library(SmarTonUi::navigation ALIAS smarton_ui_navigation)

st_add_qml_module(smarton_ui_navigation
    URI     SmarTon.Ui.Navigation
    VERSION 1.0
    NO_PLUGIN
    QML_FILES
        Routes.qml
        StNavIcon.qml
        StSidebar.qml
    IMPORTS
        SmarTon.Ui.Theme
        SmarTon.Ui.Controls
        SmarTon.Ui.Components
)

target_link_libraries(smarton_ui_navigation
    PUBLIC  SmarTonUi::controls SmarTonUi::components Qt6::Quick
    PRIVATE SmarTon::compile_settings
)
