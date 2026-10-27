# QML module: SmarTon.Ui.Controls — atoms. No knowledge of the application.
qt_add_library(smarton_ui_controls STATIC)
add_library(SmarTonUi::controls ALIAS smarton_ui_controls)

st_add_qml_module(smarton_ui_controls
    URI     SmarTon.Ui.Controls
    VERSION 1.0
    NO_PLUGIN
    QML_FILES
        StLabel.qml
        StButton.qml
        StChip.qml
        StIconButton.qml
        StCountPill.qml
        StSegmentedControl.qml
        StSwitch.qml
        StSlider.qml
        StTabBar.qml
        StEditableLabel.qml
        StCountChip.qml
        StSearchField.qml
        StRuler.qml
        StRadioOption.qml
        StTimeField.qml
        StComboBox.qml
        StIcon.qml
        StRoundedImage.qml
        StDial.qml
        StGlass.qml
        StTextField.qml
        StCheckBox.qml
        StLinkButton.qml
        StSocialButton.qml
        StOtpField.qml
        StPasswordRules.qml
    IMPORTS
        QtQuick.Effects
        SmarTon.Ui.Theme
        SmarTon.Ui.Helpers
)

target_link_libraries(smarton_ui_controls
    PUBLIC  SmarTonUi::theme SmarTonUi::helpers Qt6::Quick
    PRIVATE SmarTon::compile_settings
)
