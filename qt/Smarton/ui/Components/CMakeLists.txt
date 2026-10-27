# QML module: SmarTon.Ui.Components — molecules composed from Controls.
qt_add_library(smarton_ui_components STATIC)
add_library(SmarTonUi::components ALIAS smarton_ui_components)

st_add_qml_module(smarton_ui_components
    URI     SmarTon.Ui.Components
    VERSION 1.0
    NO_PLUGIN
    QML_FILES
        StAurora.qml
        StAvatar.qml
        StCard.qml
        StLineChart.qml
        StMediaCard.qml
        StSceneCard.qml
        StShadow.qml
        StStatCard.qml
        StSummaryHeader.qml
        StActionBar.qml
        StCalendar.qml
        StLinkDeviceCard.qml
        StConditionsStrip.qml
        StDeviceCard.qml
        StDivider.qml
        StEmptyState.qml
        StFloorPlan.qml
        StRoomCard.qml
        StRoomMap.qml
        StRoomPhotoView.qml
        StSpacePicker.qml
        StToastHost.qml
        StTopBar.qml
    IMPORTS
        QtQuick.Effects
        SmarTon.Backend
        SmarTon.Ui.Helpers
        SmarTon.Ui.Theme
        SmarTon.Ui.Controls
        SmarTon.Ui.Layouts
)

# Linked, not imported: StAurora loads the dust layer by URL (see there for
# why), and a resource nothing links against is not compiled into the binary.
if(TARGET SmarTonUi::effects)
    target_link_libraries(smarton_ui_components PUBLIC SmarTonUi::effects)
endif()

target_link_libraries(smarton_ui_components
    PUBLIC  SmarTonUi::controls SmarTonUi::layouts SmarTonUi::helpers
            SmarTon::backend Qt6::Quick
    PRIVATE SmarTon::compile_settings
)
