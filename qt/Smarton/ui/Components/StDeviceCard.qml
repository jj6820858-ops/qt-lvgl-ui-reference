import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StDeviceCard
    \inqmlmodule SmarTon.Ui.Components
    \brief Device tile: product shot over a name, its room and a power switch.

    Figma frames 07 and 19. The card is one tap target that opens the device,
    EXCEPT over the switch, which toggles power without navigating, and over
    the name, which renames in place. Getting that wrong either makes the
    switch unusable or makes the card unopenable, so both sit above the card's
    TapHandler and take the press first.

    The circular wash behind the product shot is the design's, and it is drawn
    rather than baked into the PNG so the same asset works on any background.
*/
Item {
    id: root

    property string name: ""
    property string roomName: ""
    property string kind: ""
    property url    imageSource: ""
    property bool   on: false
    /*! A command is in flight. */
    property bool   pending: false
    /*! The device stopped answering. */
    property bool   unreachable: false
    /*! The adapter has not supplied a current report yet. Unlike offline,
        this is not a device failure and must not be presented as one. */
    property bool   stale: false
    property string commandState: "idle"
    /*!
        Whether the signed-in role may operate this device.

        Disables the SWITCH, not the card: a Viewer can still open the device
        and read what it is doing, which is the whole of what "viewer" means.
        Disabling the card would also disable the tap that opens it, and a
        panel that will not let you look at your own house is not the
        restriction anybody asked for.
    */
    property bool   operable: true
    /*! Battery percentage, or -1 for a mains-powered device. A device with no
        battery is not a device at zero, which is the bug you get from testing
        the number instead of the capability. */
    property int    battery: -1
    /*! Below this the card says so. Passed in rather than assumed, so the
        threshold lives in one place - the service. */
    property int    batteryLowAt: 20

    signal toggled(bool on)
    signal activated()
    signal renamed(string name)

    implicitWidth: 300
    implicitHeight: 226

    StShadow { anchors.fill: parent; radius: Theme.radiusLg }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceRaised
        border.width: Theme.borderWidth
        border.color: Theme.surfaceRaised
        clip: true

        // Wash: a soft circle behind the product, lighter than the card.
        Rectangle {
            width: parent.width * 0.62
            height: width
            radius: width / 2
            color: Theme.textPrimary
            opacity: 0.05
            x: parent.width * 0.06
            y: -height * 0.18
        }

        /*!
            Low battery, said on the card.

            The number has been in the model since it was written and lived on
            one screen, as a figure you had to go and look at. A battery is
            the one thing about a device that stops mattering the moment you
            notice it and starts mattering badly if you never do - so it comes
            to you rather than waiting to be found.
        */
        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacing4
            spacing: Theme.spacing2
            visible: root.battery >= 0 && root.battery <= root.batteryLowAt

            StIcon {
                name: "battery"
                size: 16
                color: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }

            StLabel {
                text: qsTr("%1%").arg(root.battery)
                level: 0
                color: Theme.warning
                font.weight: Theme.fontWeightMedium
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Image {
            id: deviceImage
            source: root.imageSource
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -parent.width * 0.14
            anchors.top: parent.top
            anchors.topMargin: Theme.spacing4
            height: parent.height * 0.5
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 220
            sourceSize.height: 220
            smooth: true
            // These are tiny bundled product PNGs. Synchronous decoding is
            // intentional: with EGLFS/software rendering an async image can
            // miss the card's first paint and leave a blank tile until a
            // later scene update. Reliability matters more than a background
            // decode for seven small local assets.
            asynchronous: false
            cache: true
            onStatusChanged: {
                if (status === Image.Error)
                    console.warn("SmarTon device artwork failed:", source)
            }
        }

        // Product-specific fallback, never a generic glyph. An AC, lamp or
        // air-purifier should still look like that appliance when an adapter
        // has not supplied its own artwork or a bundled image fails to load.
        Image {
            anchors.fill: deviceImage
            visible: deviceImage.status === Image.Error || root.imageSource.length === 0
            source: {
                const type = root.kind.toLowerCase();
                if (type === "lamp")
                    return "qrc:/qt/qml/SmarTon/Resources/images/devices/pendant-lamp-teal.png";
                if (type === "conditioner" || type === "thermostat" || type === "heater")
                    return "qrc:/qt/qml/SmarTon/Resources/images/devices/air-purifier.png";
                if (type === "speaker")
                    return "qrc:/qt/qml/SmarTon/Resources/images/devices/speaker.png";
                return "qrc:/qt/qml/SmarTon/Resources/images/devices/sensor-hub.png";
            }
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 220
            sourceSize.height: 220
            smooth: true
        }

        // Footer
        StEditableLabel {
            id: nameLabel
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.right: powerSwitch.left
            anchors.rightMargin: Theme.spacing3
            anchors.bottom: roomLabel.top
            anchors.bottomMargin: 2
            text: root.name
            level: 2
            onCommitted: name => root.renamed(name)
        }

        StLabel {
            id: roomLabel
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.right: powerSwitch.left
            anchors.rightMargin: Theme.spacing3
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacing5
            text: root.unreachable ? qsTr("Not responding")
                  : root.pending ? qsTr("Command sent")
                  : root.stale ? qsTr("Awaiting device report")
                  : root.roomName
            level: 1
            color: root.unreachable ? Theme.warning
                   : (root.pending || root.stale) ? Theme.textSecondary : Theme.textMuted
        }

        StSwitch {
            id: powerSwitch
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing5
            anchors.verticalCenter: roomLabel.top
            value: root.on
            pending: root.pending
            unreachable: root.unreachable
            enabled: root.operable
            accessibleName: root.name
            // Ask, do not assume: the card re-renders when the model says the
            // device actually changed. See StSwitch for why this matters.
            onToggleRequested: requested => root.toggled(requested)
        }

        // Declared AFTER the switch so the switch wins the press. A card-wide
        // handler declared first would swallow every toggle. Disabled while
        // the name is being edited, so a tap in the field does not navigate
        // away mid-rename.
        TapHandler {
            enabled: !nameLabel.editing
            onTapped: root.activated()
        }
    }
}
