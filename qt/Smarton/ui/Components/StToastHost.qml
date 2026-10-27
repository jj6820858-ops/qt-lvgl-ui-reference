import QtQuick
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StToastHost
    \inqmlmodule SmarTon.Ui.Components
    \brief Draws whatever \c Notifications is currently saying. One per window.

    Declared once in Main.qml over everything else, so a toast raised by a
    screen survives that screen being replaced - "Saved" has to stay readable
    while the user is already navigating away.

    COLOUR CARRIES THE MEANING, AND SO DOES THE ICON. Four kinds, each with
    its own accent, tinted surface and glyph. Colour alone would be the whole
    signal for a person who cannot separate the green from the amber, and on a
    panel mounted in a hallway the viewing angle washes saturation out before
    it washes shape out - so the glyph is not decoration, it is the redundant
    channel that makes the type readable at all.

    Tinted surface rather than a fully saturated card: a solid #E31D1C banner
    at 400 px wide is a klaxon, and most errors here are "that field is
    empty". The accent lives in the rail and the icon, where it reads as a
    category rather than as an emergency.
*/
Item {
    id: root

    /*! Where it sits. Bottom-centre: the top of every screen is the header
        band, and a toast over a title is a toast over the thing that tells you
        where you are. */
    property int margin: Theme.spacing6

    readonly property var entry: Notifications.current
    readonly property string kind: root.entry === null ? Notifications.kindInfo
                                                       : root.entry.kind

    /*! The accent for \l kind. One switch, so colour and icon cannot drift. */
    readonly property color accent:
          root.kind === Notifications.kindSuccess ? Theme.success
        : root.kind === Notifications.kindWarning ? Theme.warning
        : root.kind === Notifications.kindError   ? Theme.danger
                                                  : Theme.info

    readonly property string glyph:
          root.kind === Notifications.kindSuccess ? "check"
        : root.kind === Notifications.kindWarning ? "bell"
        : root.kind === Notifications.kindError   ? "close"
                                                  : "bell"

    // Non-interactive except for the card itself, so it never swallows a tap
    // meant for the screen underneath.
    visible: Notifications.active
    z: 1000

    Timer {
        id: life

        // Restarted whenever the front of the queue changes, not on a fixed
        // schedule: two toasts in a row must each get their full time.
        interval: root.entry === null ? 1000
                                      : Notifications.durationFor(root.kind)
        running: Notifications.active
        onTriggered: Notifications.dismiss()
    }

    Connections {
        target: Notifications
        function onCurrentChanged() {
            if (Notifications.active)
                life.restart();
        }
    }

    StShadow {
        anchors.fill: card
        radius: Theme.radiusLg
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.margin
        width: Math.min(parent.width - root.margin * 2,
                        Math.max(360, body.implicitWidth + 120))
        height: Math.max(64, body.implicitHeight + Theme.spacing5 * 2)
        radius: Theme.radiusLg
        // The kind's colour, at low alpha over the raised surface. Qt.tint
        // rather than a hand-picked pair per kind, so a new kind is one line.
        color: Qt.tint(Theme.surfaceRaised,
                       Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16))
        border.width: Theme.borderWidth
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)

        // Entry and exit. Slides up rather than fading alone: on a panel a
        // fade at this size reads as a rendering glitch, and the motion is
        // what draws the eye to something that was not there a moment ago.
        opacity: Notifications.active ? 1 : 0
        transform: Translate {
            y: Notifications.active ? 0 : Theme.spacing6
            Behavior on y {
                NumberAnimation {
                    duration: Theme.durationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.durationNormal }
        }

        // The coloured rail. Redundant with the icon on purpose - it is what
        // identifies the kind from across a room, before any glyph is legible.
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 4
            radius: Theme.radiusLg
            color: root.accent

            // Square off the inner edge so the rail reads as a rail and not as
            // a floating lozenge inside the card.
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width / 2
                color: parent.color
            }
        }

        Row {
            id: body

            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.right: dismissButton.left
            anchors.rightMargin: Theme.spacing3
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing4

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                anchors.verticalCenter: parent.verticalCenter

                StIcon {
                    anchors.centerIn: parent
                    name: root.glyph
                    size: 20
                    color: root.accent
                }
            }

            Column {
                width: body.width - 32 - body.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StLabel {
                    width: parent.width
                    text: root.entry === null ? "" : root.entry.message
                    level: 1
                    font.weight: Theme.fontWeightMedium
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                StLabel {
                    width: parent.width
                    text: root.entry === null ? "" : root.entry.detail
                    level: 0
                    tone: "secondary"
                    visible: text.length > 0
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }

        StIconButton {
            id: dismissButton

            glyph: "close"
            accessibleName: qsTr("Dismiss")
            size: 32
            fill: "transparent"
            stroke: Theme.textMuted
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing3
            anchors.verticalCenter: parent.verticalCenter
            onClicked: Notifications.dismiss()
        }

        // Hovering holds it: someone reading a long error should not lose it
        // mid-sentence because a timer expired.
        HoverHandler {
            id: cardHover
            onHoveredChanged: {
                if (cardHover.hovered)
                    life.stop();
                else if (Notifications.active)
                    life.restart();
            }
        }

        // Announced as one live region, so a screen reader reads the whole
        // toast rather than the icon, the message and the button separately.
        Accessible.role: Accessible.AlertMessage
        Accessible.name: root.entry === null
                         ? ""
                         : qsTr("%1: %2").arg(root.kind).arg(root.entry.message)
    }
}
