import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Components

/*!
    \qmltype WelcomeScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief Returning-user greeting. Figma frame 02-welcome.

    The Figma centres an avatar inside four concentric orbit rings with device
    badges pinned to them. The rings are drawn rather than shipped as an image
    so they stay crisp at any size and recolour with the theme.
*/
Item {
    id: root

    property string userName: qsTr("there")
    property url    avatarSource: ""

    signal getStarted()

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacing5

        // ---- orbit graphic ----
        Item {
            id: orbit
            width: 300
            height: 300
            anchors.horizontalCenter: parent.horizontalCenter

            Canvas {
                id: rings
                anchors.fill: parent
                antialiasing: true
                onPaint: {
                    const ctx = rings.getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = Theme.outline;
                    ctx.globalAlpha = 0.45;
                    ctx.lineWidth = 1;
                    const cx = width / 2, cy = height / 2;
                    for (const r of [150, 128, 106, 84]) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                        ctx.stroke();
                    }
                    // small nodes sitting on the rings, as in the design
                    ctx.globalAlpha = 0.8;
                    const nodes = [[0, 150], [Math.PI * 0.62, 128],
                                   [Math.PI * 1.08, 140], [Math.PI * 1.55, 132]];
                    for (const [a, r] of nodes) {
                        ctx.beginPath();
                        ctx.arc(cx + r * Math.cos(a), cy + r * Math.sin(a), 3.5, 0, Math.PI * 2);
                        ctx.stroke();
                    }
                }
            }

            // The signed-in user's picture, at the centre of the orbit. This
            // is the screen the design puts a face on, and it was rendering an
            // initial because nothing passed the avatar down.
            StAvatar {
                anchors.centerIn: parent
                size: 132
                source: root.avatarSource
                name: root.userName
                ringColor: Theme.surfaceRaised
                ringWidth: 3
            }

            // Device badges pinned to the outer ring.
            Repeater {
                model: [
                    { src: "devices/pendant-lamp.png", angle: 215 },
                    { src: "devices/sensor-hub.png",   angle: 325 },
                    { src: "devices/speaker.png",      angle:  55 }
                ]
                delegate: Rectangle {
                    id: badge
                    required property var modelData
                    readonly property real rad: badge.modelData.angle * Math.PI / 180

                    width: 62
                    height: 62
                    radius: width / 2
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.outline
                    antialiasing: true
                    x: orbit.width / 2 + 138 * Math.cos(badge.rad) - width / 2
                    y: orbit.height / 2 + 138 * Math.sin(badge.rad) - height / 2

                    // Product shots are transparent PNGs drawn INSIDE the
                    // circle rather than filling it, so they need no mask -
                    // only the ones that fill their frame do.
                    Image {
                        anchors.centerIn: parent
                        width: 40
                        height: 40
                        source: "qrc:/qt/qml/SmarTon/Resources/images/" + badge.modelData.src
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 80
                        smooth: true
                        mipmap: true
                    }
                }
            }
        }

        StLabel {
            text: qsTr("Hello, %1!").arg(root.userName)
            level: 3
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StLabel {
            text: qsTr("Good morning, welcome back.")
            level: 1
            tone: "secondary"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StButton {
            text: qsTr("Get started")
            width: Theme.fieldWidth
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: root.getStarted()
        }
    }
}
