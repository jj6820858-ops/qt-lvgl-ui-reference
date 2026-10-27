import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StCountChip
    \inqmlmodule SmarTon.Ui.Controls
    \brief Outlined pill with a coloured dot, a number and a noun.
           Figma: "4 Rooms", "3 Devices", "2 Members" on the summary header.

    The dot is grey at zero and coloured once there is something to count, so
    the header doubles as a progress indicator through the wizard - which is
    what the design uses it for.
*/
Rectangle {
    id: root

    property int value: 0
    property string noun: ""
    property color accent: Theme.success
    /*!
        The ground this chip is drawn ON, so it can pick its own text and rim.

        The chip is transparent and appears on two very different backgrounds:
        the wizard's PALE summary card and the Members screen's near-black
        header band. It hard-coded \c surfaceDeep for its text - correct on the
        pale card, and on the dark band it rendered #101113 on #101113, so the
        Members header showed an empty outlined box with a lone dot in it.

        Passed in rather than sampled, because an item cannot read the pixels
        behind it; \l foreground is then measured from this by contrast.
    */
    property color ground: Theme.surfaceDeep

    /*! Derived, never set: see Appearance::readableOn(). */
    readonly property color foreground: Theme.textOn(root.ground)

    implicitWidth: content.implicitWidth + Theme.spacing5 * 2
    implicitHeight: 46
    radius: Theme.radiusSm
    color: "transparent"
    border.width: Theme.borderWidth
    // The rim has to survive both grounds too. On the pale card the measured
    // #606873 is right; on the dark band it disappears, so it steps to the
    // foreground at low alpha - the same edge, relative to whatever it is on.
    border.color: Theme.isLight(root.ground)
                  ? Theme.outlineSubtle          // measured #606873
                  : Qt.rgba(root.foreground.r, root.foreground.g,
                            root.foreground.b, 0.35)

    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("%1 %2").arg(root.value).arg(root.noun)

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacing2

        Rectangle {
            width: 14
            height: 14
            radius: 7
            color: "transparent"
            border.width: 2
            border.color: root.value > 0 ? root.accent : Theme.textDisabled
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 6
                height: 6
                radius: 3
                color: root.value > 0 ? root.accent : Theme.textDisabled
            }
        }

        StLabel {
            text: String(root.value)
            level: 1
            color: root.foreground
            font.weight: Theme.fontWeightBold
            anchors.verticalCenter: parent.verticalCenter
        }

        StLabel {
            text: root.noun
            level: 1
            color: root.foreground
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
