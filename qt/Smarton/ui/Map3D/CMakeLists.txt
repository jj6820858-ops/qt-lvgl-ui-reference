# QML module: SmarTon.Ui.Map3D — the 3D map view.
#
# Built only when Qt Quick 3D was found (see the root CMakeLists). Its own
# module rather than a file in Components, so that the Quick3D dependency stops
# here: putting it in Components would make every card, chip and top bar in the
# app un-buildable on a Qt without the module.
qt_add_library(smarton_ui_map3d STATIC)
add_library(SmarTonUi::map3d ALIAS smarton_ui_map3d)

st_add_qml_module(smarton_ui_map3d
    URI     SmarTon.Ui.Map3D
    VERSION 1.0
    NO_PLUGIN
    QML_FILES
        StFloorPlan3D.qml
        StWalkPad.qml
    IMPORTS
        QtQuick3D
        QtQuick3D.Helpers
        SmarTon.Ui.Helpers
        SmarTon.Ui.Theme
        SmarTon.Ui.Controls
)

target_link_libraries(smarton_ui_map3d
    PUBLIC
        SmarTonUi::controls
        SmarTonUi::helpers
        Qt6::Quick
        Qt6::Quick3D
    PRIVATE SmarTon::compile_settings
)
