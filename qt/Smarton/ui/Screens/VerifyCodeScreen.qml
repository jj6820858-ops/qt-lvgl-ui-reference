import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts

/*!
    \qmltype VerifyCodeScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief Four-digit code entry. Figma frame 04-verify-code.

    The design sets the destination address in bold inside the body sentence.
    That is done with StyledText rather than three stacked labels so the
    sentence still wraps as one paragraph at any width.

    SCOPE. SmarTon has no mail transport, so no code is actually sent. The
    screen is wired to the view model, which today accepts any four digits and
    is the single place a real delivery channel would be added.
*/
Item {
    id: root

    property string destination: ""

    signal verified(string code)
    signal resendRequested()

    StAuthPage {
        anchors.fill: parent
        columnWidth: Theme.fieldWidth
        spacing: 0

        StLabel {
            width: parent.width
            text: qsTr("Verify Code")
            level: 4
            horizontalAlignment: Text.AlignHCenter
        }

        Item { width: 1; height: Theme.spacing3 }

        StLabel {
            width: parent.width
            text: qsTr("We just sent a 4-digit verification code to <b>%1</b>. Enter the code in the box below to continue.")
                    .arg(root.destination)
            level: 1
            tone: "secondary"
            textFormat: Text.StyledText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        Item { width: 1; height: Theme.spacing8 }

        StOtpField {
            id: otp
            width: parent.width
            height: 56
            digits: 4
        }

        Item { width: 1; height: Theme.spacing6 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacing2

            StLabel {
                text: qsTr("Didn't receive a code?")
                level: 1
                tone: "secondary"
                anchors.verticalCenter: parent.verticalCenter
            }

            StLinkButton {
                text: qsTr("Resend Code")
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    otp.clear();
                    root.resendRequested();
                }
            }
        }

        Item { width: 1; height: Theme.spacing4 }

        StButton {
            width: parent.width
            text: qsTr("Next")
            // The design shows Next as always-orange. It is disabled until the
            // code is complete because an enabled button that does nothing is
            // worse than a disabled one that explains itself.
            enabled: otp.complete
            onClicked: root.verified(otp.code)
        }
    }
}
