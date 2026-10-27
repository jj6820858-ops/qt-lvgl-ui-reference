import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StDeviceDialog
    \inqmlmodule SmarTon.Ui.Dialogs
    \brief Device prompt over a dimmed dashboard. Figma frame 08.

    Derives from T.Dialog so modality, focus trapping, Esc handling and the
    scrim come from Qt rather than being reimplemented - the parts of a dialog
    that are easy to get subtly wrong.

    The frame dims the whole page behind a 55% scrim and floats the device's
    own product shot inside faint rings. Both are here; the rings are drawn so
    they work for any device's artwork.
*/
T.Dialog {
    id: root

    property string heading: ""
    property string message: ""
    property url    imageSource: ""
    property string confirmText: qsTr("Turn off")
    property string dismissText: qsTr("Dismiss")

    modal: true
    anchors.centerIn: T.Overlay.overlay
    padding: 0
    implicitWidth: 540
    implicitHeight: 400
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    background: Rectangle {
        radius: Theme.radiusLg
        color: Theme.surfaceDeep
        border.width: Theme.borderWidth
        border.color: Theme.outline
    }

    contentItem: Item {
        Canvas {
            id: rings
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: -40
            width: 300
            height: 240
            antialiasing: true
            onPaint: {
                const ctx = rings.getContext("2d");
                ctx.reset();
                ctx.strokeStyle = Theme.outline;
                ctx.globalAlpha = 0.35;
                ctx.lineWidth = 1;
                for (let r = 150; r > 60; r -= 22) {
                    ctx.beginPath();
                    ctx.arc(rings.width / 2, rings.height / 2 + 20, r, 0, Math.PI * 2);
                    ctx.stroke();
                }
            }
        }

        Image {
            id: hero
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: -30
            height: 160
            source: root.imageSource
            fillMode: Image.PreserveAspectFit
            sourceSize.height: 320
            smooth: true
            asynchronous: true
        }

        StIconButton {
            glyph: "close"
            size: 36
            accessibleName: qsTr("Close")
            fill: "transparent"
            stroke: Theme.textSecondary
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacing4
            onClicked: root.reject()
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: hero.bottom
            anchors.margins: Theme.spacing6
            anchors.topMargin: Theme.spacing5
            spacing: Theme.spacing2

            StLabel {
                width: parent.width
                text: root.heading
                level: 3
                horizontalAlignment: Text.AlignHCenter
            }

            StLabel {
                width: parent.width
                text: root.message
                level: 1
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacing6
            spacing: Theme.spacing4

            StButton {
                width: 178
                variant: "secondary"
                text: root.dismissText
                onClicked: root.reject()
            }

            StButton {
                width: 278
                text: root.confirmText
                onClicked: root.accept()
            }
        }
    }

    T.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.55)
    }
}
