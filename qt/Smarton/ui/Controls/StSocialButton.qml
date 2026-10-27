import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StSocialButton
    \inqmlmodule SmarTon.Ui.Controls
    \brief Outlined provider button. Figma: Google / Facebook / Apple on Login.

    \warning SmarTon authenticates against LOCAL accounts in SQLite. There is
             no identity provider integration, so these are rendered exactly as
             designed but are DISABLED. Enabling one without a real OAuth flow
             behind it would be a button that lies about what it does.
             See docs/adr/0007-social-login-disabled.md.
*/
T.Button {
    id: root

    /*! google | facebook | apple */
    property string provider: "google"

    implicitWidth: Theme.fieldWidth
    implicitHeight: Theme.controlHeightSm
    enabled: false                       // deliberate - see the warning above
    focusPolicy: Qt.NoFocus

    // Announced with the reason. A disabled control that says only "dimmed"
    // leaves a screen-reader user guessing whether it is broken.
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.description: qsTr("Unavailable: SmarTon uses local accounts.")
    // Not hoverEnabled: a disabled control that reacts to the pointer is
    // telling the user it will respond, and this one will not. The tooltip
    // below is how it explains itself instead.

    contentItem: Item {
        Row {
            anchors.centerIn: parent
            spacing: Theme.spacing3

            // Provider glyph, drawn rather than shipped as three more PNGs.
            Canvas {
                id: glyph
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: true
                opacity: 0.45

                onPaint: {
                    const ctx = glyph.getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Theme.textSecondary;
                    if (root.provider === "facebook") {
                        ctx.beginPath();
                        ctx.arc(10, 10, 9, 0, Math.PI * 2);
                        ctx.fill();
                        ctx.fillStyle = Theme.surface;
                        ctx.fillRect(9, 7, 4, 11);
                    } else if (root.provider === "apple") {
                        ctx.beginPath();
                        ctx.ellipse(4, 6, 12, 13);
                        ctx.fill();
                        ctx.beginPath();
                        ctx.ellipse(9, 0, 5, 5);
                        ctx.fill();
                    } else {
                        ctx.lineWidth = 3;
                        ctx.strokeStyle = Theme.textSecondary;
                        ctx.beginPath();
                        ctx.arc(10, 10, 7, 0.5, Math.PI * 1.9);
                        ctx.stroke();
                        ctx.fillRect(10, 8.5, 7, 3);
                    }
                }
            }

            Rectangle {
                width: 1
                height: 20
                color: Theme.outline
                opacity: 0.5
                anchors.verticalCenter: parent.verticalCenter
            }

            StLabel {
                text: root.text
                level: 1
                tone: "disabled"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    T.ToolTip.visible: providerHover.hovered
    T.ToolTip.delay: 500
    T.ToolTip.text: qsTr("Sign-in providers are not available: SmarTon uses local accounts.")

    HoverHandler { id: providerHover }

    background: Rectangle {
        radius: Theme.radius
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.outlineSubtle
        opacity: 0.55
    }
}
