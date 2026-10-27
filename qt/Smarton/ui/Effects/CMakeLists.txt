# QML module: SmarTon.Ui.Effects — optional decorative layers.
#
# Built only when Qt Quick Particles is available. See StDustLayer for why it
# is isolated rather than imported from Components.
qt_add_library(smarton_ui_effects STATIC)
add_library(SmarTonUi::effects ALIAS smarton_ui_effects)

st_add_qml_module(smarton_ui_effects
    URI     SmarTon.Ui.Effects
    VERSION 1.0
    NO_PLUGIN
    QML_FILES
        StDustLayer.qml
    IMPORTS
        QtQuick.Particles
        SmarTon.Ui.Theme
)

target_link_libraries(smarton_ui_effects
    PUBLIC  SmarTonUi::theme Qt6::Quick Qt6::QuickParticles
    PRIVATE SmarTon::compile_settings
)
