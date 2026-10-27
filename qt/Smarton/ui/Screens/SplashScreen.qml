import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype SplashScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief Brand splash. Figma frame 01-splash.

    The Figma stacks logo over a tall block of copy. On a 1024x600 panel the
    same elements are centred with tighter rhythm; the logo keeps its designed
    proportions.
*/
Item {
    id: root

    /*! Emitted once the dwell time has elapsed. */
    signal finished()

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacing6
        width: 520

        Image {
            id: mark
            source: "qrc:/qt/qml/SmarTon/Resources/images/brand/logo-splash.png"
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 300
            smooth: true
            opacity: 0
            NumberAnimation on opacity {
                to: 1; duration: Theme.durationSlow; easing.type: Easing.OutCubic
            }
        }

        StLabel {
            text: qsTr("Easy living with your smart home")
            level: 4
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }

        StLabel {
            text: qsTr("Get your smart devices in one place and manage all of these with a few taps.")
            level: 1
            tone: "secondary"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    Timer {
        interval: Theme.splashDwell
        running: true
        onTriggered: root.finished()
    }
}
