import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StPasswordRules
    \inqmlmodule SmarTon.Ui.Controls
    \brief Live password-policy feedback. Figma: Reset password screen.

    Shows a strength bar plus one line per rule, ticking green as each is met.
    The rules here MUST stay in step with whatever the service layer enforces -
    a UI that accepts what the backend rejects is worse than no feedback.
*/
Column {
    id: root

    property string password: ""

    readonly property bool hasLength: root.password.length >= 8
    readonly property bool hasNumberOrSymbol: /[0-9!-\/:-@\[-`{-~]/.test(root.password)
    readonly property bool hasMixedCase: /[a-z]/.test(root.password) && /[A-Z]/.test(root.password)
    readonly property int  metCount: (root.hasLength ? 1 : 0)
                                   + (root.hasNumberOrSymbol ? 1 : 0)
                                   + (root.hasMixedCase ? 1 : 0)
    readonly property bool acceptable: root.metCount === 3

    spacing: Theme.spacing2

    // The rule list is live feedback, so it is announced as one status line
    // rather than three items a reader has to walk to find the failing one.
    Accessible.role: Accessible.StaticText
    Accessible.name: root.acceptable
                     ? qsTr("Password meets all requirements")
                     : qsTr("Password meets %1 of 3 requirements").arg(root.metCount)

    // Strength bar: red -> amber -> green as rules are met.
    Rectangle {
        width: parent.width
        height: 3
        radius: 2
        color: Theme.surfaceRaised

        Rectangle {
            width: parent.width * (root.metCount / 3)
            height: parent.height
            radius: parent.radius
            color: root.metCount >= 3 ? Theme.success
                 : root.metCount === 2 ? Theme.warning
                 : Theme.danger
            Behavior on width  { NumberAnimation { duration: Theme.durationNormal } }
            Behavior on color  { ColorAnimation  { duration: Theme.durationNormal } }
        }
    }

    Repeater {
        model: [
            { label: qsTr("At least 8 characters"),            met: root.hasLength },
            { label: qsTr("At least one number (0-9) or symbol"), met: root.hasNumberOrSymbol },
            { label: qsTr("Lowercase (a-z) and uppercase (A-Z)"), met: root.hasMixedCase }
        ]

        delegate: Row {
            id: rule
            required property var modelData
            spacing: Theme.spacing2

            Item {
                width: 14
                height: 14
                anchors.verticalCenter: parent.verticalCenter

                // Bullet when unmet, tick when met - matches the Figma exactly.
                Rectangle {
                    anchors.centerIn: parent
                    width: 4; height: 4; radius: 2
                    color: Theme.textSecondary
                    visible: !rule.modelData.met
                }
                StIcon {
                    anchors.centerIn: parent
                    name: "check"
                    size: 16
                    color: Theme.success
                    visible: rule.modelData.met
                }
            }

            StLabel {
                text: rule.modelData.label
                level: 1
                color: rule.modelData.met ? Theme.success : Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }
        }
    }
}
