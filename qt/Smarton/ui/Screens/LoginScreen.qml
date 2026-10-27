import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components

/*!
    \qmltype LoginScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief Credential entry. Figma frame 03-login.

    REFLOW NOTE. The Figma frame is 1440x1024 and stacks the three provider
    buttons vertically, which needs 1024 px of height. The target panel has
    600. Everything that carries meaning is preserved - column width 480,
    field height 52, button height 54, radius 12, the 2 px #1268CC focus ring,
    the "or" rule, the closing rule and the sign-up line - and the only change
    is that the three provider buttons sit in one row instead of a column.
    Their labels shorten to the provider name because 152 px cannot hold
    "Login with Facebook" at 14 px without eliding.

    The providers are rendered exactly as designed but are DISABLED: SmarTon
    authenticates against local SQLite accounts and there is no OAuth client
    behind them. See docs/adr/0007-social-login-disabled.md.
*/
Item {
    id: root

    /*! smarton::models::AuthViewModel. */
    required property var viewModel

    signal forgotPassword()
    signal signUpRequested()

    /*! Focus the first empty field whenever the screen is shown. */
    function takeFocus(): void {
        if (emailField.text.length === 0)
            emailField.forceActiveFocus();
        else
            passwordField.forceActiveFocus();
    }

    function submit(): void {
        if (!root.viewModel.busy)
            root.viewModel.signIn(emailField.text, passwordField.text);
    }

    StAuthPage {
        anchors.fill: parent
        columnWidth: Theme.fieldWidth
        spacing: 0

        StLabel {
            width: parent.width
            text: qsTr("Login")
            level: 4
            horizontalAlignment: Text.AlignHCenter
        }

        Item { width: 1; height: Theme.spacing3 }

        StLabel {
            width: parent.width
            text: qsTr("Welcome back! Please enter your details.")
            level: 1
            tone: "secondary"
            horizontalAlignment: Text.AlignHCenter
        }

        // Why the panel is showing a login form again. Without this an idle
        // lock is indistinguishable from a crash that dumped you back here.
        Item {
            id: lockSlot

            width: parent.width
            // MEASURED FROM THE NOTICE, not computed alongside it.
            //
            // This slot and the notice inside it each worked out their own
            // height, and the two disagreed by exactly Theme.spacing3 - the
            // notice's top margin, which the slot did not account for. So the
            // notice overflowed its slot by 12 px, and the Column placed the
            // email field over that overflow: the notice's last line was drawn
            // underneath the field, and the pair read as a third text box with
            // clipped text in it.
            //
            // One source of truth removes the class of bug, not just this
            // instance. No loop: the notice's height comes from the label's
            // implicitHeight, which depends on WIDTH, which comes from the
            // Column - never from this height.
            height: root.viewModel.lockedForInactivity
                    ? Theme.spacing3 + lockNoticeBox.height + Theme.spacing3
                    : Theme.spacing6

            Rectangle {
                id: lockNoticeBox

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Theme.spacing3
                // Padding on BOTH sides of the text. The previous single
                // spacing4 was the total, which left 8 px shared between top
                // and bottom and the text sitting hard against the border.
                height: lockNotice.implicitHeight + Theme.spacing4 * 2
                radius: Theme.radiusSm
                color: Theme.surface
                border.width: Theme.borderWidth
                border.color: Theme.outline
                visible: root.viewModel.lockedForInactivity

                StLabel {
                    id: lockNotice

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.spacing4
                    anchors.rightMargin: Theme.spacing4
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Locked after a period of inactivity. Sign in to continue.")
                    level: 1
                    tone: "secondary"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }
        }

        StTextField {
            id: emailField
            width: parent.width
            placeholderText: qsTr("Email")
            inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
            enabled: !root.viewModel.busy
            onTextChanged: root.viewModel.clearError()
            // The chain is written out rather than left to Qt's automatic
            // order: the reveal toggle inside the password field is focusable
            // too, so the natural order would put it between the two fields.
            KeyNavigation.tab: passwordField
            KeyNavigation.backtab: signUpLink
            onAccepted: passwordField.forceActiveFocus()
        }

        Item { width: 1; height: Theme.spacing4 }

        StTextField {
            id: passwordField
            width: parent.width
            placeholderText: qsTr("Password")
            password: true
            enabled: !root.viewModel.busy
            onTextChanged: root.viewModel.clearError()
            KeyNavigation.tab: remember
            KeyNavigation.backtab: emailField
            onAccepted: root.submit()
        }

        Item { width: 1; height: Theme.spacing2 }

        // Auth failures are reported here, not on a field: the service returns
        // one indistinguishable error for a wrong user and a wrong password,
        // and marking a specific field would leak which one was wrong.
        StLabel {
            width: parent.width
            text: root.viewModel.errorText
            level: 1
            color: Theme.danger
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            visible: root.viewModel.errorText.length > 0
            height: visible ? implicitHeight : 0
        }

        Item { width: 1; height: Theme.spacing1 }

        StCheckBox {
            id: remember

            text: qsTr("Remember information")
            enabled: !root.viewModel.busy
            // Two-way, and written through on every toggle rather than read at
            // submit: unticking it means "forget what you have on me", which
            // has to happen even if the user then walks away without signing
            // in. See AuthViewModel::setRememberMe().
            onToggled: root.viewModel.rememberMe = remember.checked

            // A Binding rather than `checked: viewModel.rememberMe`, because a
            // checkable control assigns to its own `checked` when clicked and
            // that assignment DESTROYS a plain binding. The box would then
            // stop following the model - invisible here, where nothing else
            // writes it, and a real bug the first time something does.
            Binding {
                target: remember
                property: "checked"
                value: root.viewModel.rememberMe
                restoreMode: Binding.RestoreBindingOrValue
            }
            KeyNavigation.tab: submitButton
            KeyNavigation.backtab: passwordField
        }

        StButton {
            id: submitButton

            width: parent.width
            KeyNavigation.tab: forgotLink
            KeyNavigation.backtab: remember
            text: root.viewModel.busy ? qsTr("Signing in…") : qsTr("Login")
            enabled: !root.viewModel.busy
                     && emailField.text.length > 0
                     && passwordField.text.length > 0
            onClicked: root.submit()
        }

        StLinkButton {
            id: forgotLink

            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Forget password?")
            KeyNavigation.tab: signUpLink
            KeyNavigation.backtab: submitButton
            onClicked: root.forgotPassword()
        }

        StDivider {
            width: parent.width
            text: qsTr("or")
        }

        Item { width: 1; height: Theme.spacing4 }

        Row {
            id: providerRow

            width: parent.width
            spacing: Theme.spacing3

            readonly property int cellWidth: (providerRow.width - providerRow.spacing * 2) / 3

            Repeater {
                model: [
                    { provider: "google",   label: qsTr("Google")   },
                    { provider: "facebook", label: qsTr("Facebook") },
                    { provider: "apple",    label: qsTr("Apple")    }
                ]

                delegate: StSocialButton {
                    required property var modelData
                    width: providerRow.cellWidth
                    provider: modelData.provider
                    text: modelData.label
                }
            }
        }

        Item { width: 1; height: Theme.spacing4 }

        StDivider { width: parent.width }

        Item { width: 1; height: Theme.spacing1 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacing1

            StLabel {
                text: qsTr("First time here?")
                level: 1
                tone: "secondary"
                anchors.verticalCenter: parent.verticalCenter
            }

            StLinkButton {
                id: signUpLink

                text: qsTr("Sign up for free")
                emphasised: true
                KeyNavigation.tab: emailField
                KeyNavigation.backtab: forgotLink
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.signUpRequested()
            }
        }
    }

    Component.onCompleted: {
        // Pre-fill from the last remembered sign-in. The username survives
        // even when the token does not - an expired session should still land
        // on a form that needs only the password, not on two empty fields.
        //
        // Before takeFocus(), which decides between the two fields by whether
        // the email is already filled: run the other way round it would always
        // choose the email field and the pre-fill would be pointless.
        if (emailField.text.length === 0)
            emailField.text = root.viewModel.rememberedUser;

        root.takeFocus();
    }
}
