import QtQuick
import QtQuick.Controls.Basic as QQC
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Components
import SmarTon.Ui.Dialogs
import SmarTon.Ui.Helpers

/*!
    \qmltype DeviceDetailScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief One device: hero image, controls, media and scenes. Figma frame 21.

    Two columns, as designed. The left column's rows (Status, Battery, Volume)
    are separated by hairlines rather than boxed, matching the frame - the
    controls are the emphasis, not their containers.

    Rows appear only when the device HAS that capability: a lamp reports no
    battery and no volume, so it shows neither, rather than showing a greyed
    slider that implies the hardware has one.
*/
Item {
    id: root

    /*!
        True only when this screen was pushed onto something that can be
        popped.

        Read from the enclosing StackView's LIVE depth rather than hard-coded.
        Every screen with a back arrow used to assert it unconditionally,
        including the ones the sidebar opens as a root destination - so Members
        and Statistics drew a back button that could not do anything, and
        pressing it did nothing at all. A control that is visible and inert is
        worse than one that is absent: it teaches people the app ignores them.

        The attached property resolves because THIS item is what was pushed;
        it is null in the gallery, where screens are shown outside a stack.
    */
    readonly property bool canGoBack:
        QQC.StackView.view !== null && QQC.StackView.view.depth > 1

    /*! True when this device reports a thermostat target - the seed marks air
        conditioners with one. Drives which primary control the right column
        shows; see the climate card. */
    readonly property bool hasThermostat:
        root.deviceData.targetC !== undefined && root.deviceData.targetC >= 0

    /*! smarton::models::HomeViewModel. */
    required property var viewModel
    required property string deviceId

    property var deviceData: ({})
    property bool pendingPowerState: false
    readonly property var runLimits: [
        { name: qsTr("No panel limit"), seconds: 0 },
        { name: qsTr("5 minutes"), seconds: 300 },
        { name: qsTr("15 minutes"), seconds: 900 },
        { name: qsTr("30 minutes"), seconds: 1800 },
        { name: qsTr("1 hour"), seconds: 3600 },
        { name: qsTr("2 hours"), seconds: 7200 }
    ]

    function runLimitIndex(): int {
        const current = deviceData.maxRunSeconds === undefined ? 0 : deviceData.maxRunSeconds;
        for (let i = 0; i < runLimits.length; ++i)
            if (runLimits[i].seconds === current)
                return i;
        return 0;
    }

    signal backRequested()
    /*! The picker's "Create a new space" row. */
    signal addSpaceRequested()

    readonly property bool hasBattery: (root.deviceData.battery === undefined
                                        ? -1 : root.deviceData.battery) >= 0
    readonly property bool hasVolume: (root.deviceData.volume === undefined
                                       ? -1 : root.deviceData.volume) >= 0
    /*! From the model, not computed here: the threshold is the service's and
        every surface that mentions a battery reads the same one. */
    readonly property bool batteryLow:
        root.deviceData.batteryLow === undefined ? false : root.deviceData.batteryLow
    /*! A continuous output setting: brightness on a lamp, mist on a
        humidifier. -1 from the model means the hardware has none, which is
        why this is a capability test and not a value test for zero. */
    readonly property bool hasLevel: (root.deviceData.level === undefined
                                      ? -1 : root.deviceData.level) >= 0
    readonly property bool hasEnergy: (root.deviceData.powerWatts === undefined
                                       ? -1 : root.deviceData.powerWatts) >= 0

    /*!
        How many control rows this device actually shows.

        Counted rather than assumed, because the stack has to FIT. On the
        1024x600 panel the left column is about 436 px tall and a speaker
        wants five rows: at the design's 96 px each that is 480, and a Column
        anchored to the bottom that does not fit grows upwards - straight
        through the header. It looked fine on a desktop window and was broken
        on the only screen that matters.
    */
    readonly property int controlRowCount:
        1
        + (root.hasBattery ? 1 : 0)
        + (root.hasVolume ? 1 : 0)
        + (root.hasLevel ? 1 : 0)
        + (root.hasEnergy ? 1 : 0)
        + (root.viewModel.canAdminister ? 2 : 0)

    /*! The design's 96 where there is room, down to a still-tappable 58 where
        there is not. Floored at the touch target plus its padding rather than
        at whatever divides evenly - a row that fits and cannot be hit is not
        a row that fits. */
    readonly property int controlRowHeight:
        Math.max(Theme.touchTarget + 14,
                 Math.min(96, Math.floor(leftColumn.height * 0.66
                                         / Math.max(1, root.controlRowCount))))

    /*! The glyph for the level control, by kind. The WORD comes from the view
        model (one place, four screens); the picture is presentation and stays
        here with the rest of the icon choices. */
    readonly property string levelGlyph: {
        switch (root.deviceData.kind) {
        case "lamp":        return "bulb";
        case "humidifier":  return "humidity";
        case "diffuser":    return "humidity";
        case "conditioner": return "modeWind";
        default:            return "devices";
        }
    }

    /*! The rooms this device could be moved to. Re-read on every model change
        rather than cached: the wizard can add a room while this page is open. */
    property var roomChoices: []

    readonly property int roomIndex: {
        for (let i = 0; i < root.roomChoices.length; ++i) {
            if (root.roomChoices[i].id === root.deviceData.roomId)
                return i;
        }
        return -1;
    }

    function reload(): void {
        root.deviceData = root.viewModel.device(root.deviceId);
        root.roomChoices = root.viewModel.roomChoices();
    }

    Component.onCompleted: {
        root.reload();
        root.viewModel.setRoomFilter(root.deviceData.roomId === undefined
                                     ? "" : root.deviceData.roomId);
    }

    Connections {
        target: root.viewModel
        function onDeviceChanged(changedId) {
            if (changedId === root.deviceId)
                root.reload();
        }
    }

    // ---- header ------------------------------------------------------------
    StTopBar {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacing6
        anchors.bottomMargin: 0
        showBack: root.canGoBack
        titleRowHeight: 92
        eyebrow: root.deviceData.roomName === undefined ? "" : root.deviceData.roomName
        title: root.deviceData.name === undefined ? "" : root.deviceData.name
        onBackRequested: root.backRequested()

        trailing: Component {
            StSpacePicker {
                spaceName: root.viewModel.spaceName
                thumbnailSource: root.viewModel.spaceImage
                // The list and both actions, which the picker has always offered
                // and nothing ever supplied - so the dropdown showed one
                // unchanging row and a Create action that did nothing.
                spaces: root.viewModel.spaces
                onSpaceSelected: index => {
                    const chosen = root.viewModel.spaces[index];
                    if (chosen !== undefined)
                        root.viewModel.switchSpace(chosen.spaceId);
                }
                onCreateSpaceRequested: root.addSpaceRequested()
            }
        }
    }

    // ---- left column: hero + controls ---------------------------------------
    Item {
        id: leftColumn

        anchors.left: parent.left
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing6
        width: parent.width * 0.52

        // Concentric rings behind the product, as in the frame. Drawn, not an
        // asset: they recolour with the theme and stay crisp at any size.
        Canvas {
            id: rings
            anchors.horizontalCenter: hero.horizontalCenter
            anchors.verticalCenter: hero.verticalCenter
            // Bounded by the column's HEIGHT as well as its width. Capped on
            // width alone, a wide column produced a ring set taller than the
            // space it had, and since it centres on the hero the excess went
            // upwards - straight through the bottom of the header band.
            width: Math.min(leftColumn.width,
                            leftColumn.height * 0.72,
                            hero.height * 1.6)
            height: width
            antialiasing: true
            onPaint: {
                const ctx = rings.getContext("2d");
                ctx.reset();
                ctx.strokeStyle = Theme.outline;
                ctx.globalAlpha = 0.35;
                ctx.lineWidth = 1;
                const cx = rings.width / 2;
                const cy = rings.height / 2;
                for (let r = rings.width * 0.5; r > rings.width * 0.2; r -= rings.width * 0.075) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.stroke();
                }
            }
        }

        Image {
            id: hero
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacing4
            // WHATEVER THE CONTROLS LEAVE, not a fixed 0.44 of the column. How
            // many control rows there are depends on what the device can do -
            // a speaker shows five, a lamp four, a sensor hub two - so a hero
            // sized by a constant fraction is a hero that overlaps the first
            // row on the device with the most capabilities. The product photo
            // is the thing with slack here; the controls are not.
            anchors.bottom: controls.top
            anchors.bottomMargin: Theme.spacing4
            source: root.deviceData.image === undefined ? "" : root.deviceData.image
            fillMode: Image.PreserveAspectFit
            sourceSize.height: 640
            smooth: true
            asynchronous: true
        }

        Column {
            id: controls

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacing6
            spacing: 0

            StControlRow {
                width: parent.width
                label: qsTr("Status")

                StSwitch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    trackWidth: 72
                    trackHeight: 38
                    showStateText: true
                    enabled: root.viewModel.canOperate
                    accessibleName: qsTr("Power")
                    value: root.deviceData.isOn === undefined ? false : root.deviceData.isOn
                    pending: root.deviceData.isPending === undefined
                             ? false : root.deviceData.isPending
                    unreachable: root.deviceData.isReachable === undefined
                                 ? false : !root.deviceData.isReachable
                    onToggleRequested: requested =>
                        (root.deviceData.requiresConfirmation && requested)
                        ? (root.pendingPowerState = requested, safetyDialog.open())
                        : root.viewModel.setDevicePower(root.deviceId, requested)
                }
            }

            StControlRow {
                width: parent.width
                label: qsTr("Connection")

                StLabel {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    level: 1
                    color: root.deviceData.isReachable === false ? Theme.warning : Theme.textSecondary
                    text: root.deviceData.isReachable === false ? qsTr("Not responding")
                          : root.deviceData.isPending ? qsTr("Command sent")
                          : root.deviceData.isStale ? qsTr("Awaiting report")
                          : root.deviceData.signalStrength >= 0
                            ? qsTr("Online · signal %1").arg(root.deviceData.signalStrength)
                            : qsTr("Online")
                }
            }

            StControlRow {
                width: parent.width
                label: qsTr("Energy")
                visible: root.hasEnergy

                StLabel {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    level: 1
                    color: Theme.textSecondary
                    text: root.deviceData.energyKwh >= 0
                          ? qsTr("%1 W · %2 kWh").arg(Math.round(root.deviceData.powerWatts))
                                                   .arg(Number(root.deviceData.energyKwh).toFixed(2))
                          : qsTr("%1 W").arg(Math.round(root.deviceData.powerWatts))
                }
            }

            StControlRow {
                width: parent.width
                label: qsTr("Battery")
                visible: root.hasBattery

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing3

                    StLabel {
                        text: qsTr("%1 %").arg(root.deviceData.battery === undefined
                                               ? 0 : root.deviceData.battery)
                        level: 2
                        font.weight: Theme.fontWeightMedium
                        // Amber below the threshold, and the threshold is the
                        // service's - so the card, this row and anything else
                        // that mentions a battery agree about what "low" is.
                        color: root.batteryLow ? Theme.warning : Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 14
                        height: 22
                        radius: 3
                        color: "transparent"
                        border.width: Theme.borderWidth
                        border.color: root.batteryLow ? Theme.warning : Theme.success
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            width: 6
                            height: 2
                            color: root.batteryLow ? Theme.warning : Theme.success
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            height: (parent.height - 4)
                                    * (root.deviceData.battery === undefined
                                       ? 0 : root.deviceData.battery) / 100
                            radius: 1
                            color: root.batteryLow ? Theme.warning : Theme.success
                        }
                    }
                }
            }

            StControlRow {
                width: parent.width
                label: qsTr("Volume")
                visible: root.hasVolume

                StSlider {
                    accessibleName: qsTr("Volume")
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.62
                    glyph: "volume"
                    enabled: root.viewModel.canOperate
                    modelValue: root.deviceData.volume === undefined
                                ? 0 : root.deviceData.volume
                    // It used to have no handler at all: the slider moved
                    // under the finger, nothing was sent, and letting go put
                    // it back. A control that can be operated and does
                    // nothing is the worst of the three states it could be
                    // in - worse than absent, worse than disabled.
                    onMoved: root.viewModel.setDeviceVolume(root.deviceId,
                                                            Math.round(value))
                }
            }

            /*!
                The device's own output: brightness, mist, diffusion, fan.

                One row for all of them rather than one per kind, because it
                is one number with one range and one control - what changes is
                the word, and the word comes from the view model so the four
                screens that could show this cannot disagree about it.
            */
            StControlRow {
                width: parent.width
                label: root.viewModel.levelLabel(root.deviceId)
                visible: root.hasLevel

                StSlider {
                    accessibleName: root.viewModel.levelLabel(root.deviceId)
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.62
                    glyph: root.levelGlyph
                    modelValue: root.deviceData.level === undefined
                                ? 0 : root.deviceData.level
                    // Dimming a lamp that is off is a request to have it come
                    // on dim, not a no-op, so the control stays live - but the
                    // device being unreachable IS a reason to stop asking.
                    enabled: root.viewModel.canOperate
                             && (root.deviceData.isReachable === undefined
                                 ? true : root.deviceData.isReachable)
                    onMoved: root.viewModel.setDeviceLevel(root.deviceId,
                                                           Math.round(value))
                }
            }

            /*!
                What you can do TO the device, as opposed to with it.

                The frames show none of this - 21 and 22 are a speaker and an
                air conditioner being operated, not administered - but the
                model has supported renaming, moving and unlinking a device
                since the wizard was written, and until now the only place any
                of it was reachable was the wizard's link step. A capability
                the app has and never offers is not restraint, it is a dead
                end: the answer to "I put this lamp in the wrong room" was to
                delete it and set it up again.
            */
            StControlRow {
                width: parent.width
                label: qsTr("Name")
                // Hidden rather than disabled, unlike the operating controls
                // above. A greyed switch tells a Viewer what the device is
                // doing; a greyed rename row tells them nothing at all, and
                // three of them turn the page into a list of things they
                // cannot have.
                visible: root.deviceData.deviceId !== undefined
                         && root.viewModel.canAdminister

                StEditableLabel {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    // Sized by its own content and pinned to the right edge,
                    // so it grows leftwards into the row's empty middle when
                    // the editor opens instead of pushing the row wider.
                    level: 2
                    text: root.deviceData.name === undefined
                          ? "" : root.deviceData.name
                    onCommitted: newName =>
                        root.viewModel.renameDevice(root.deviceId, newName)
                }
            }

            StControlRow {
                width: parent.width
                label: qsTr("Room")
                visible: root.deviceData.deviceId !== undefined
                         && root.viewModel.canAdminister
                showRule: false

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing3

                    StComboBox {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 260
                        model: root.roomChoices
                        textRole: "name"
                        accessibleName: qsTr("Room")
                        // Read from the device each time the model changes,
                        // not remembered: the same device is movable from the
                        // wizard, and a remembered index would go stale the
                        // moment it was.
                        currentIndex: root.roomIndex
                        onActivated: index => {
                            const choice = root.roomChoices[index];
                            if (choice !== undefined)
                                root.viewModel.setDeviceRoom(root.deviceId, choice.id);
                        }
                    }

                    StIconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "trash"
                        size: 48
                        radius: Theme.radiusSm
                        fill: "transparent"
                        borderColor: Theme.outline
                        borderWidth: Theme.borderWidth
                        stroke: Theme.danger
                        accessibleName: qsTr("Remove this device")
                        onClicked: removeDialog.open()
                    }
                }
            }

            StControlRow {
                width: parent.width
                label: qsTr("Maximum run time")
                visible: root.viewModel.canInstall
                         && (root.deviceData.requiresConfirmation || root.deviceData.maxRunSeconds > 0)
                showRule: false
                StComboBox {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 210
                    model: root.runLimits
                    textRole: "name"
                    currentIndex: root.runLimitIndex()
                    accessibleName: qsTr("Maximum run time")
                    onActivated: index => root.viewModel.setDeviceMaxRunSeconds(
                                      root.deviceId, root.runLimits[index].seconds)
                }
            }
        }
    }

    // ---- right column: media + scenes ---------------------------------------
    Column {
        anchors.left: leftColumn.right
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing6
        // Was 0, which is why the Status switch appeared to run into the
        // scenes panel: the switch is right-anchored inside the left column,
        // so with no gutter its track ended exactly where the panel began and
        // the two read as one overlapping element. The columns need the same
        // gap between them as the cards inside them have.
        anchors.leftMargin: Theme.cardGap
        spacing: Theme.spacing5

        /*!
            The thermostat panel, for devices that have one.

            SWAPPED WITH the media card rather than added below it. Frame 21 is
            a speaker and frame 22 is an air conditioner, and they are the same
            screen with the top-right panel exchanged - which is the design
            saying that a device's PRIMARY control is whatever that device
            actually does. A screen that showed both would be showing every
            device a transport bar it has no use for.
        */
        StCard {
            id: climate

            width: parent.width
            height: parent.height * 0.55
            visible: root.hasThermostat

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacing5
                spacing: Theme.spacing4

                StLabel { text: qsTr("Set Temperature"); level: 2 }

                StDial {
                    id: dial

                    anchors.horizontalCenter: parent.horizontalCenter
                    // Square, and bounded by whichever axis runs out first, so
                    // the dial never overflows the card on a short window.
                    width: Math.min(parent.width,
                                    climate.height - modeRow.height
                                    - Theme.spacing5 * 4 - 30)
                    height: width
                    enabled: root.viewModel.canOperate
                    from: root.viewModel.minTargetC()
                    to: root.viewModel.maxTargetC()
                    value: root.deviceData.targetC === undefined
                           ? 24 : root.deviceData.targetC
                    onMoved: next => root.viewModel.setDeviceTarget(root.deviceId, next)
                }

                Row {
                    id: modeRow

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacing3

                    Repeater {
                        model: [
                            { mode: "cold",  glyph: "modeCold",  label: qsTr("Cold")  },
                            { mode: "wind",  glyph: "modeWind",  label: qsTr("Wind")  },
                            { mode: "sleep", glyph: "modeSleep", label: qsTr("Sleep") },
                            { mode: "swing", glyph: "modeSwing", label: qsTr("Swing") }
                        ]

                        delegate: Rectangle {
                            id: modeButton

                            required property var modelData

                            readonly property bool current:
                                root.deviceData.mode === modeButton.modelData.mode

                            width: (modeRow.width - Theme.spacing3 * 3) / 4
                            height: 96
                            radius: Theme.radiusSm
                            // Measured: #E25319 active, #606873 idle.
                            color: modeButton.current   ? Theme.primary
                                 : modeHover.hovered    ? Theme.hoveredFill(Theme.outlineSubtle, true)
                                                        : Theme.outlineSubtle

                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacing2

                                StIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: modeButton.modelData.glyph
                                    size: 24
                                    // Measured against the fill it sits on, so
                                    // the active button's glyph stays legible
                                    // whatever the accent is set to.
                                    color: modeButton.current
                                           ? Theme.textOnPrimary : Theme.textPrimary
                                }

                                StLabel {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modeButton.modelData.label
                                    level: 1
                                    color: modeButton.current
                                           ? Theme.textOnPrimary : Theme.textPrimary
                                }
                            }

                            opacity: root.viewModel.canOperate
                                     ? 1 : Theme.disabledOpacity

                            HoverHandler {
                                id: modeHover
                                enabled: root.viewModel.canOperate
                            }
                            TapHandler {
                                enabled: root.viewModel.canOperate
                                onTapped: root.viewModel.setDeviceMode(
                                              root.deviceId, modeButton.modelData.mode)
                            }

                            Accessible.role: Accessible.RadioButton
                            Accessible.name: modeButton.modelData.label
                            Accessible.checked: modeButton.current
                            Accessible.onPressAction: root.viewModel.setDeviceMode(
                                root.deviceId, modeButton.modelData.mode)
                        }
                    }
                }
            }
        }

        StMediaCard {
            id: media
            width: parent.width
            height: parent.height * 0.55
            room: root.deviceData.roomName === undefined ? "" : root.deviceData.roomName
            track: qsTr("My life")
            artist: qsTr("STRASFERA")
            playing: true
            artworkSource: "qrc:/qt/qml/SmarTon/Resources/images/rooms/living-interior.png"
            // Speakers only, and never alongside the climate card - frames 21
            // and 22 are the same screen with this panel exchanged, not
            // stacked. hasThermostat is redundant today (nothing is both a
            // speaker and a thermostat) and is stated anyway, because the
            // rule is "one primary control", not "speakers get a transport".
            visible: root.deviceData.kind === "speaker" && !root.hasThermostat
            onPlayPauseRequested: media.playing = !media.playing
        }

        Item {
            width: parent.width
            // Whatever the primary panel above did not take. Written from the
            // two siblings rather than from `media` alone, which was correct
            // when the media card was the only thing that could be there.
            height: parent.height
                    - (media.visible ? media.height + Theme.spacing5 : 0)
                    - (climate.visible ? climate.height + Theme.spacing5 : 0)

            StShadow { anchors.fill: parent; radius: Theme.radiusLg }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusLg
                color: Theme.surfaceRaised

                Row {
                    id: sceneHeader
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing5
                    spacing: Theme.spacing3

                    StLabel {
                        text: qsTr("Scenes")
                        level: 3
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StCountPill {
                        value: root.viewModel.scenes.count
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                ListView {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: sceneHeader.bottom
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacing4
                    anchors.topMargin: Theme.spacing2
                    clip: true
                    spacing: 0
                    model: root.viewModel.scenes

                    delegate: StSceneCard {
                        required property var model
                        required property int index

                        width: ListView.view.width
                        compact: true
                        name: model.name
                        days: model.days
                        timeRange: model.timeRange
                        enabled: model.isEnabled

                        onToggled: requested =>
                            root.viewModel.scenes.setEnabled(index, requested)
                        onRenamed: newName =>
                            root.viewModel.scenes.rename(index, newName)
                    }
                }
            }
        }
    }

    /*!
        Unlinking is destructive in the only sense that matters here: the
        device leaves the space and its room, name and settings go with it.
        It is recoverable - it reappears in the wizard's nearby list - and the
        dialog says so, because a warning that overstates what it is warning
        about is one people learn to click through.
    */
    StConfirmDialog {
        id: removeDialog

        parent: root
        title: qsTr("Remove %1?").arg(root.deviceData.name === undefined
                                      ? "" : root.deviceData.name)
        message: qsTr("It leaves this space and goes back to the nearby list, "
                      + "where you can link it again. Its room and settings are not kept.")
        acceptText: qsTr("Remove")
        rejectText: qsTr("Keep it")
        destructive: true
        onAccepted: {
            root.viewModel.unlinkDevice(root.deviceId);
            Notifications.info(qsTr("Device removed"),
                               qsTr("%1 is back in the nearby list.")
                                   .arg(root.deviceData.name === undefined
                                        ? "" : root.deviceData.name));
            root.backRequested();
        }
    }

    // Turning a dangerous appliance OFF is always immediate. Turning it ON,
    // unlocking it, or opening it is deliberately a two-step action.
    StConfirmDialog {
        id: safetyDialog

        parent: root
        title: qsTr("Confirm %1").arg(root.deviceData.name === undefined
                                       ? qsTr("device") : root.deviceData.name)
        message: qsTr("This device is marked as requiring confirmation. Verify that it is safe to operate before continuing.")
        acceptText: root.pendingPowerState ? qsTr("Turn on") : qsTr("Continue")
        rejectText: qsTr("Cancel")
        destructive: true
        artworkSource: root.deviceData.image === undefined ? "" : root.deviceData.image
        onAccepted: root.viewModel.setDevicePower(root.deviceId, root.pendingPowerState)
    }

    /*!
        Label on the left, control on the right, hairline underneath.

        No default-property alias: the caller's control is a plain sibling
        anchored to the row, which keeps the rule below it rather than
        capturing it into a slot along with this file's own children.
    */
    component StControlRow: Item {
        id: controlRow

        property string label: ""
        property bool showRule: true

        // From the screen, not a constant: see controlRowHeight.
        implicitHeight: root.controlRowHeight

        StLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: controlRow.label
            level: 3
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.outline
            opacity: 0.4
            visible: controlRow.showRule
        }
    }
}
