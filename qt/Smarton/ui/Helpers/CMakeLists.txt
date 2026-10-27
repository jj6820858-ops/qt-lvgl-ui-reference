# QML module: SmarTon.Ui.Helpers — logic and lookup, no visual types OF ITS OWN.
#
# It was pure JavaScript once. It now holds four singletons, one of which
# (Backdrop) HOLDS a reference to an Item, so the module links Qt6::Quick. The
# rule that still applies is the useful one: nothing here draws anything. A
# type that renders belongs in Controls or Components, where the layer order
# puts it.
qt_add_library(smarton_ui_helpers STATIC)
add_library(SmarTonUi::helpers ALIAS smarton_ui_helpers)

set_source_files_properties(Backdrop.qml        PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(FocusHelper.qml     PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(Notifications.qml   PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(FloorPlanHelper.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

st_add_qml_module(smarton_ui_helpers
    URI     SmarTon.Ui.Helpers
    VERSION 1.0
    NO_PLUGIN
    QML_FILES
        Backdrop.qml
        FocusHelper.qml
        FloorPlanHelper.qml
        Notifications.qml
        Formatters.js
        Geometry.js
    DEPENDENCIES
        QtQml
        QtQuick
)

target_link_libraries(smarton_ui_helpers
    PUBLIC  Qt6::Qml Qt6::Quick
    PRIVATE SmarTon::compile_settings
)
