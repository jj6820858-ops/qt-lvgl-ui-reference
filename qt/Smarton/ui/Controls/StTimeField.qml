import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StTimeField
    \inqmlmodule SmarTon.Ui.Controls
    \brief HH:MM with an AM/PM pair. Figma frames 24 and 25.

    12-hour with an explicit meridiem because the design is, and because on a
    wall panel "01:15" without AM/PM is a genuine ambiguity for a schedule.
    The value is kept as hour/minute/pm rather than a formatted string, so the
    caller never has to parse its own display text back.
*/
Row {
    id: root

    property int hour: 11        // 1..12
    property int minute: 15      // 0..59
    property bool pm: false
    property bool highlighted: false

    readonly property string text:
        qsTr("%1:%2 %3")
            .arg(String(root.hour).padStart(2, "0"))
            .arg(String(root.minute).padStart(2, "0"))
            .arg(root.pm ? qsTr("PM") : qsTr("AM"))

    signal changed()

    spacing: Theme.spacing3

    property string accessibleName: qsTr("Time")

    Accessible.role: Accessible.SpinBox
    Accessible.name: root.accessibleName
    Accessible.description: root.text

    Rectangle {
        width: 88
        height: 52
        radius: Theme.radiusSm
        color: root.highlighted ? Theme.info : Theme.surface
        anchors.verticalCenter: parent.verticalCenter

        Row {
            anchors.centerIn: parent
            spacing: 2

            StSpinDigit {
                value: root.hour
                minimum: 1
                maximum: 12
                onStepped: next => { root.hour = next; root.changed(); }
            }

            StLabel { text: ":"; level: 2; anchors.verticalCenter: parent.verticalCenter }

            StSpinDigit {
                value: root.minute
                minimum: 0
                maximum: 59
                step: 5
                onStepped: next => { root.minute = next; root.changed(); }
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        StMeridiem {
            text: qsTr("AM")
            active: !root.pm
            onPicked: { root.pm = false; root.changed(); }
        }

        StMeridiem {
            text: qsTr("PM")
            active: root.pm
            onPicked: { root.pm = true; root.changed(); }
        }
    }

    /*! Tap the top half to increase, the bottom half to decrease. */
    component StSpinDigit: Item {
        id: digit

        property int value: 0
        property int minimum: 0
        property int maximum: 59
        property int step: 1

        signal stepped(int next)

        implicitWidth: digitLabel.implicitWidth + 6
        implicitHeight: 36
        anchors.verticalCenter: parent === null ? undefined : parent.verticalCenter

        StLabel {
            id: digitLabel
            anchors.centerIn: parent
            text: String(digit.value).padStart(2, "0")
            level: 2
            font.weight: Theme.fontWeightBold
        }

        TapHandler {
            onTapped: function (point) {
                const up = point.position.y < digit.height / 2;
                const span = digit.maximum - digit.minimum + 1;
                const delta = up ? digit.step : -digit.step;
                digit.stepped(digit.minimum
                              + (((digit.value - digit.minimum + delta) % span) + span) % span);
            }
        }
    }

    component StMeridiem: Rectangle {
        id: meridiem

        property bool active: false
        property alias text: meridiemLabel.text

        signal picked()

        width: 52
        height: 52
        radius: Theme.radiusSm
        color: meridiem.active ? Theme.primary : Theme.surfaceDeep

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        StLabel {
            id: meridiemLabel
            anchors.centerIn: parent
            level: 1
            color: meridiem.active ? Theme.textOnPrimary : Theme.textSecondary
            font.weight: Theme.fontWeightMedium
        }

        TapHandler {
            onTapped: meridiem.picked()
        }
    }
}
