import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StMediaCard
    \inqmlmodule SmarTon.Ui.Components
    \brief Now-playing panel. Figma frame 21, and the mini bar on frame 19.

    NOT A MEDIA PLAYER. SmarTon has no audio backend and no Spotify
    integration; this renders the design and reports its transport taps. The
    progress bar advances only while \l playing, driven by a local timer, so
    the screen is not frozen - and it is clearly labelled as a preview in the
    screens that host it rather than pretending a track is streaming.
*/
Item {
    id: root

    property string provider: qsTr("Spotify")
    property string room: ""
    property string track: ""
    property string artist: ""
    property url    artworkSource: ""
    property bool   playing: false
    property int    durationSeconds: 165
    property real   progress: 0.28
    /*! mini shows just the bar; full shows artwork and the provider header. */
    property bool   mini: false

    signal playPauseRequested()
    signal previousRequested()
    signal nextRequested()

    implicitWidth: 380
    implicitHeight: root.mini ? 96 : 500

    // Local clock so the bar moves. Real playback would drive `progress` from
    // the backend and this timer would go.
    Timer {
        interval: 1000
        running: root.playing
        repeat: true
        onTriggered: root.progress = (root.progress + 1 / root.durationSeconds) % 1
    }

    StShadow { anchors.fill: parent; radius: Theme.radiusLg }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: root.mini ? Theme.primary : Theme.surfaceRaised
        clip: true

        // ---- full layout --------------------------------------------------
        Column {
            visible: !root.mini
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacing5
            spacing: Theme.spacing4

            Item {
                width: parent.width
                height: 44

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    StLabel { text: root.provider; level: 2; font.weight: Theme.fontWeightMedium }
                    StLabel { text: root.room; level: 1; tone: "secondary" }
                }

                StIconButton {
                    glyph: "chevronDown"
                    size: 36
                    fill: "transparent"
                    stroke: Theme.textSecondary
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StRoundedImage {
                width: parent.width
                height: width * 0.62
                radius: Theme.radiusSm
                source: root.artworkSource
            }

            StProgressRow { width: parent.width }

            Item {
                width: parent.width
                height: 56

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    StLabel { text: root.track; level: 2; font.weight: Theme.fontWeightBold }
                    StLabel { text: root.artist; level: 1; tone: "secondary" }
                }

                StTransport {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    prominent: true
                }
            }
        }

        // ---- mini layout --------------------------------------------------
        Item {
            visible: root.mini
            anchors.fill: parent
            anchors.margins: Theme.spacing4

            StRoundedImage {
                id: miniArt
                width: 56
                height: 56
                radius: width / 2
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                source: root.artworkSource
            }

            Column {
                anchors.left: miniArt.right
                anchors.leftMargin: Theme.spacing4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                // The mini bar is filled with the accent, so its text is
                // measured against the accent rather than against the page.
                StLabel {
                    text: root.track
                    level: 2
                    color: Theme.textOnPrimary
                    font.weight: Theme.fontWeightBold
                }
                StLabel { text: root.artist; level: 0; color: Theme.textOnPrimary }
            }

            StTransport {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                prominent: false
                onAccent: true
            }
        }
    }

    /*! Elapsed bar plus remaining time. Inline: used twice, only here. */
    component StProgressRow: Item {
        id: progressRow

        implicitHeight: 20

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: remaining.left
            anchors.rightMargin: Theme.spacing4
            anchors.verticalCenter: parent.verticalCenter
            height: 3
            radius: 1.5
            color: Theme.surface

            Rectangle {
                width: parent.width * root.progress
                height: parent.height
                radius: parent.radius
                color: Theme.primary
            }

            Rectangle {
                x: parent.width * root.progress - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                radius: 6
                color: Theme.textPrimary
            }
        }

        StLabel {
            id: remaining
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("%1:%2 min")
                    .arg(Math.floor(root.durationSeconds * (1 - root.progress) / 60))
                    .arg(String(Math.floor(root.durationSeconds * (1 - root.progress)) % 60)
                            .padStart(2, "0"))
            level: 1
            tone: "secondary"
        }
    }

    /*! Previous / play-pause / next. */
    component StTransport: Row {
        id: transport

        property bool prominent: false
        /*! Sitting on an accent-filled surface rather than on the page. */
        property bool onAccent: false

        readonly property color glyphColor: transport.onAccent ? Theme.textOnPrimary
                                                               : Theme.textPrimary

        spacing: Theme.spacing3

        StIconButton {
            glyph: "skipBack"
            accessibleName: qsTr("Previous track")
            size: 36
            fill: "transparent"
            stroke: transport.prominent ? Theme.primary : transport.glyphColor
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.previousRequested()
        }

        Rectangle {
            width: transport.prominent ? 48 : 36
            height: width
            radius: width / 2
            color: transport.prominent ? Theme.primary : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            StIcon {
                anchors.centerIn: parent
                name: root.playing ? "pause" : "play"
                size: 20
                color: transport.prominent ? Theme.textOnPrimary : transport.glyphColor
            }

            TapHandler {
                onTapped: root.playPauseRequested()
            }
        }

        StIconButton {
            glyph: "skipForward"
            accessibleName: qsTr("Next track")
            size: 36
            fill: "transparent"
            stroke: transport.prominent ? Theme.primary : transport.glyphColor
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.nextRequested()
        }
    }
}
