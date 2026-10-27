import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts

/*!
    \qmltype ResetPasswordScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief New-password entry with live policy feedback. Figma frame 05.

    The strength bar and rule list sit immediately under the first field, as in
    the design. The rules rendered here are the SAME predicate the view model
    enforces before it will accept a reset - a UI that green-ticks a password
    the backend then rejects is worse than showing no rules at all.
*/
Item {
    id: root

    /*! smarton::models::AuthViewModel. */
    required property var viewModel

    signal completed()

    readonly property bool _matches:
        confirmField.text.length > 0 && confirmField.text === passwordField.text
    readonly property bool canSubmit:
        rules.acceptable && root._matches && !root.viewModel.busy

    StAuthPage {
        anchors.fill: parent
        columnWidth: Theme.fieldWidth
        spacing: 0

        StLabel {
            width: parent.width
            text: qsTr("Reset password")
            level: 4
            horizontalAlignment: Text.AlignHCenter
        }

        Item { width: 1; height: Theme.spacing8 }

        StTextField {
            id: passwordField
            width: parent.width
            placeholderText: qsTr("New password")
            password: true
            enabled: !root.viewModel.busy
            KeyNavigation.tab: confirmField
            KeyNavigation.backtab: resetButton
        }

        Item { width: 1; height: Theme.spacing3 }

        StPasswordRules {
            id: rules
            width: parent.width
            password: passwordField.text
        }

        Item { width: 1; height: Theme.spacing5 }

        StTextField {
            id: confirmField
            width: parent.width
            placeholderText: qsTr("Confirm new password")
            password: true
            enabled: !root.viewModel.busy
            // Only complain once there is something to complain about: an error
            // that appears on the first keystroke trains people to ignore it.
            errorText: confirmField.text.length > 0 && !root._matches
                       ? qsTr("Passwords do not match") : ""
            KeyNavigation.tab: resetButton
            KeyNavigation.backtab: passwordField
            onAccepted: if (root.canSubmit) root.completed()
        }

        Item { width: 1; height: Theme.spacing8 }

        StButton {
            id: resetButton

            width: parent.width
            KeyNavigation.tab: passwordField
            KeyNavigation.backtab: confirmField
            text: root.viewModel.busy ? qsTr("Submitting…") : qsTr("Reset password")
            enabled: root.canSubmit
            onClicked: root.completed()
        }
    }
}
