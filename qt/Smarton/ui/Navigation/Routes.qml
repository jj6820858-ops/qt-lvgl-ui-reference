pragma Singleton

import QtQuick

/*!
    \qmltype Routes
    \inqmlmodule SmarTon.Ui.Navigation
    \brief Every navigable destination, named once.

    Screens push route CONSTANTS, never file paths. A renamed or moved QML file
    then breaks in exactly one place instead of everywhere it was referenced,
    and the set of destinations is reviewable in a single file.
*/
QtObject {
    // pre-login
    readonly property string splash:        "splash"
    readonly property string welcome:       "welcome"
    readonly property string login:         "login"
    readonly property string verifyCode:    "verifyCode"
    readonly property string resetPassword: "resetPassword"

    // shell
    readonly property string spaces:     "spaces"
    readonly property string rooms:      "rooms"
    readonly property string devices:    "devices"
    readonly property string members:    "members"
    readonly property string statistics: "statistics"
    readonly property string operations: "operations"
    readonly property string settings:   "settings"

    /*! Sidebar entries, in the order the Figma shows them. */
    readonly property var navigation: [
        { route: "spaces",     label: qsTr("Spaces")     },
        { route: "rooms",      label: qsTr("Rooms")      },
        { route: "devices",    label: qsTr("Devices")    },
        { route: "members",    label: qsTr("Members")    },
        { route: "statistics", label: qsTr("Statistics") },
        { route: "operations", label: qsTr("Operations") }
    ]
}
