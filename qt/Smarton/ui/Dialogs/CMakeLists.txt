# QML module: SmarTon.Ui.Dialogs — modal surfaces.
qt_add_library(smarton_ui_dialogs STATIC)
add_library(SmarTonUi::dialogs ALIAS smarton_ui_dialogs)

st_add_qml_module(smarton_ui_dialogs
    URI     SmarTon.Ui.Dialogs
    VERSION 1.0
    NO_PLUGIN
    QML_FILES
        StConfirmDialog.qml
        StDeviceDialog.qml
        StAddRoomSheet.qml
    IMPORTS
        SmarTon.Ui.Theme
        SmarTon.Ui.Controls
        SmarTon.Ui.Layouts
)

target_link_libraries(smarton_ui_dialogs
    PUBLIC  SmarTonUi::controls SmarTonUi::layouts Qt6::Quick Qt6::QuickControls2
    PRIVATE SmarTon::compile_settings
)
