import QtQuick
import QtQuick.Controls.Basic as QQC
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Components

/*!
    \qmltype SceneWizardScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief "Create a new scenario", steps 1-3. Figma frames 24 and 25.

    Same shape as SpaceWizardScreen and for the same reason: shared chrome,
    a Loader over the step. Three steps - name, schedule, devices - matching
    the "2 | 3" and "3 | 3" counters in the frames.

    WHAT A SCENE DOES NOT DO YET. It records which devices it covers and when
    it should run, and nothing executes it: there is no scheduler in SmarTon,
    so a saved scene is a stored intention. The screen says so rather than
    letting someone set a 7 a.m. wake-up that will never fire - which is the
    kind of silent failure that makes people distrust a whole product.
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

    /*! smarton::models::HomeViewModel. */
    required property var viewModel
    /*! Empty creates a new scene; otherwise the wizard edits that one. */
    property string sceneId: ""

    property int step: 1
    readonly property int stepCount: 3

    property string sceneName: qsTr("New scenario")
    property string roomId: ""
    property var    selectedDays: []
    property int    calendarYear: new Date().getFullYear()
    property int    calendarMonth: new Date().getMonth() + 1
    property string repeatMode: "custom"      // everyday | weekdays | custom

    signal finished()
    signal cancelled()

    readonly property string scheduleDays: {
        if (root.repeatMode === "everyday")
            return qsTr("Everyday");
        if (root.repeatMode === "weekdays")
            return qsTr("Week days");
        if (root.selectedDays.length === 0)
            return qsTr("No dates");
        return qsTr("%n date(s)", "", root.selectedDays.length);
    }

    readonly property string scheduleRange:
        qsTr("%1 - %2").arg(timeOn.text).arg(timeOff.text)

    function back(): void {
        if (root.step > 1)
            root.step -= 1;
        else
            root.cancelled();
    }

    /*!
        What step 3 decided, handed over when its component is destroyed.

        The step owns the editing and this screen owns the saving, so the
        rows travel across rather than the screen reaching into a Loader's
        item - which is null the moment the step changes, and Save happens
        from a different step than the one that built the list.
    */
    property var pendingActions: []

    function commit(): void {
        if (root.sceneId.length === 0) {
            root.sceneId = root.viewModel.addScene(root.sceneName, root.roomId,
                                                   root.scheduleDays, root.scheduleRange);
        } else {
            root.viewModel.renameScene(root.sceneId, root.sceneName);
            root.viewModel.setSceneSchedule(root.sceneId, root.scheduleDays,
                                            root.scheduleRange);
        }

        if (root.sceneId.length === 0)
            return;

        // Only the ticked rows. An empty list is meaningful rather than a
        // failure to choose: it puts the scene back to acting on its whole
        // room, which is where every new scene starts.
        const chosen = [];
        for (let i = 0; i < root.pendingActions.length; ++i) {
            const row = root.pendingActions[i];
            if (!row.included)
                continue;
            chosen.push({
                deviceId: row.deviceId,
                on: row.on,
                level: row.level,
                targetC: row.targetC,
            });
        }
        root.viewModel.setSceneActions(root.sceneId, chosen);
    }

    function advance(): void {
        if (root.step < root.stepCount) {
            root.step += 1;
            return;
        }
        root.commit();
        root.finished();
    }

    QQC.Dialog {
        id: previewDialog
        parent: QQC.Overlay.overlay
        modal: true
        title: qsTr("Scene test — no devices changed")
        standardButtons: QQC.Dialog.Close
        width: Math.min(root.width - Theme.spacing6 * 2, 620)
        property var actions: []

        contentItem: Column {
            spacing: Theme.spacing3
            width: parent.width
            StLabel {
                width: parent.width
                text: qsTr("This is a dry run. It lists the commands that the schedule would send; it does not control any appliance.")
                level: 1; tone: "secondary"; wrapMode: Text.WordWrap
            }
            Repeater {
                model: previewDialog.actions
                delegate: StLabel {
                    required property var modelData
                    width: parent.width
                    text: modelData.name + (modelData.effectiveOn ? qsTr(" — switch on") : qsTr(" — switch off"))
                    level: 1
                }
            }
            StLabel {
                visible: previewDialog.actions.length === 0
                text: qsTr("No available devices are included in this scene.")
                level: 1; tone: "muted"
            }
        }
    }

    // Time state lives here, not in a step body: the Loader destroys the body
    // on every step change, and a schedule that resets when you go Back is
    // not a schedule anyone will trust.
    StTimeField {
        id: timeOn
        visible: false
        hour: 11
        minute: 15
        pm: false
    }

    StTimeField {
        id: timeOff
        visible: false
        hour: 1
        minute: 15
        pm: true
    }

    StTopBar {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacing6
        anchors.bottomMargin: 0
        titleRowHeight: 100
        centred: true
        showBack: root.canGoBack
        title: root.sceneId.length === 0 ? qsTr("Create a new scenario")
                                         : qsTr("Edit scenario")
        subtitle: root.step === 1 ? qsTr("Name and room")
                : root.step === 2 ? qsTr("Schedule")
                                  : qsTr("Devices")
        onBackRequested: root.back()

        trailing: Component {
            Column {
                spacing: 0

                StLabel {
                    text: qsTr("Step")
                    level: 1
                    tone: "secondary"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 2
                    anchors.horizontalCenter: parent.horizontalCenter

                    StLabel {
                        text: String(root.step)
                        level: 1
                        font.weight: Theme.fontWeightBold
                    }
                    StLabel { text: "|"; level: 1; tone: "muted" }
                    StLabel { text: String(root.stepCount); level: 1; tone: "secondary" }
                }
            }
        }
    }

    StSummaryHeader {
        id: summary

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.margins: Theme.spacing6
        // Was -Theme.spacing6, the same negative margin the space wizard had:
        // it pulled the pale summary card 24 px UP into the header band, so it
        // cut across the bottom of the artwork and sat over the title row.
        // Both wizards had their own copy of it.
        anchors.topMargin: Theme.spacing4
        title: root.sceneName
        subtitle: qsTr("%1  |  %2").arg(root.scheduleDays).arg(root.scheduleRange)
        thumbnailSource: root.viewModel.spaceImage
        counts: [
            { value: root.roomId.length > 0 ? 1 : 0, noun: qsTr("Room"),
              accent: Theme.success },
            { value: root.viewModel.roomDevices.count, noun: qsTr("Devices"),
              accent: Theme.accentViolet }
        ]
        onRenamed: name => root.sceneName = name
    }

    Loader {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: summary.bottom
        anchors.bottom: actions.top
        anchors.margins: Theme.spacing6
        // Each step is a different Component, so focus has to be placed again
        // every time the body swaps - onCurrentItemChanged in the shell only
        // fires once, when the wizard itself is pushed.
        onLoaded: FocusHelper.focusFirstField(body)
        sourceComponent: root.step === 1 ? nameStep
                       : root.step === 2 ? scheduleStep
                                         : devicesStep
    }

    StActionBar {
        id: actions

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing6
        hint: qsTr("Customise your new scenario")
        secondaryText: qsTr("Dismiss")
        auxiliaryVisible: root.sceneId.length > 0 && root.step === root.stepCount
        auxiliaryText: qsTr("Test scene")
        primaryText: root.step === root.stepCount ? qsTr("Save scenario")
                                                  : qsTr("Continue")
        primaryEnabled: root.step !== 1 || root.roomId.length > 0
        onSecondaryTriggered: root.cancelled()
        onPrimaryTriggered: root.advance()
        onAuxiliaryTriggered: {
            previewDialog.actions = root.viewModel.scenePreview(root.sceneId)
            previewDialog.open()
        }
    }

    // ---- step 1: name and room ---------------------------------------------
    Component {
        id: nameStep

        Item {
            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width, 640)
                spacing: Theme.spacing4

                StLabel {
                    width: parent.width
                    text: qsTr("What is this scenario called?")
                    level: 1
                    tone: "secondary"
                }

                StTextField {
                    id: sceneNameField
                    width: parent.width
                    text: root.sceneName
                    onTextChanged: root.sceneName = sceneNameField.text
                }

                StLabel {
                    width: parent.width
                    text: qsTr("Which room does it run in?")
                    level: 1
                    tone: "secondary"
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacing3

                    Repeater {
                        model: root.viewModel.roomChoices()

                        delegate: StChip {
                            required property var modelData

                            text: modelData.name
                            selected: root.roomId === modelData.id
                            onClicked: {
                                root.roomId = modelData.id;
                                root.viewModel.setRoomFilter(modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- step 2: schedule ---------------------------------------------------
    Component {
        id: scheduleStep

        Item {
            Item {
                id: scheduleHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 56

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StLabel { text: qsTr("Schedule"); level: 3 }
                    StLabel {
                        text: qsTr("How often do you want it to be?")
                        level: 1
                        tone: "secondary"
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing3

                    Repeater {
                        model: [
                            { mode: "everyday", label: qsTr("Every day") },
                            { mode: "weekdays", label: qsTr("Week days") },
                            { mode: "custom",   label: qsTr("Custom date") }
                        ]

                        delegate: StChip {
                            required property var modelData

                            text: modelData.label
                            selected: root.repeatMode === modelData.mode
                            onClicked: root.repeatMode = modelData.mode
                        }
                    }
                }
            }

            StCalendar {
                id: calendar

                anchors.left: parent.left
                anchors.top: scheduleHeader.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Theme.spacing4
                width: parent.width * 0.62
                enabled: root.repeatMode === "custom"
                opacity: enabled ? 1 : 0.45
                year: root.calendarYear
                month: root.calendarMonth
                selectedDays: root.selectedDays

                onDayToggled: function (day) {
                    const days = root.selectedDays.slice();
                    const at = days.indexOf(day);
                    if (at === -1)
                        days.push(day);
                    else
                        days.splice(at, 1);
                    root.selectedDays = days;
                }

                onMonthStepped: function (delta) {
                    let month = root.calendarMonth + delta;
                    let year = root.calendarYear;
                    if (month < 1) { month = 12; year -= 1; }
                    if (month > 12) { month = 1; year += 1; }
                    root.calendarMonth = month;
                    root.calendarYear = year;
                }
            }

            StCard {
                anchors.left: calendar.right
                anchors.right: parent.right
                anchors.top: calendar.top
                anchors.leftMargin: Theme.spacing5
                height: 260

                StLabel {
                    id: workingTitle
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing5
                    text: qsTr("Working time")
                    level: 2
                    font.weight: Theme.fontWeightBold
                }

                StLabel {
                    id: workingSubtitle
                    anchors.left: parent.left
                    anchors.top: workingTitle.bottom
                    anchors.leftMargin: Theme.spacing5
                    anchors.topMargin: 2
                    text: qsTr("Select the desired time interval")
                    level: 1
                    tone: "secondary"
                }

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: workingSubtitle.bottom
                    anchors.margins: Theme.spacing5
                    height: 60

                    StLabel {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Time On")
                        level: 1
                    }

                    StTimeField {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        hour: timeOn.hour
                        minute: timeOn.minute
                        pm: timeOn.pm
                        highlighted: true
                        onChanged: {
                            timeOn.hour = hour;
                            timeOn.minute = minute;
                            timeOn.pm = pm;
                        }
                    }
                }

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacing5
                    height: 60

                    StLabel {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Time Off")
                        level: 1
                    }

                    StTimeField {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        hour: timeOff.hour
                        minute: timeOff.minute
                        pm: timeOff.pm
                        onChanged: {
                            timeOff.hour = hour;
                            timeOff.minute = minute;
                            timeOff.pm = pm;
                        }
                    }
                }
            }

            StLabel {
                anchors.left: calendar.right
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.spacing5
                anchors.bottomMargin: Theme.spacing4
                text: qsTr("This schedule runs. SceneScheduler checks every minute and acts on the edges — when the window opens and when it closes — so a scene fires once at each boundary rather than every minute in between.")
                level: 0
                tone: "muted"
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
    }

    // ---- step 3: devices ----------------------------------------------------
    Component {
        id: devicesStep

        Item {
            id: devicesStepRoot

            /*!
                What this scene will do, one row per device in scope.

                Held here rather than written as you go, because a scene is
                edited as a whole: half a scene saved because someone left
                mid-edit is a schedule that fires at six in the morning and
                does something nobody asked for. It commits on Save with the
                rest of the wizard.

                Rows carry the device's CAPABILITIES alongside the values, so
                the panel knows whether to draw a brightness slider before it
                knows what this scene sets it to.
            */
            property var rows: []

            function load(): void {
                const chosen = root.sceneId.length > 0
                             ? root.viewModel.sceneActions(root.sceneId) : [];
                const byId = {};
                for (let i = 0; i < chosen.length; ++i)
                    byId[chosen[i].deviceId] = chosen[i];

                const out = [];
                const candidates = root.viewModel.sceneCandidates(root.roomId);
                for (let c = 0; c < candidates.length; ++c) {
                    const device = candidates[c];
                    const saved = byId[device.deviceId];
                    out.push({
                        deviceId:  device.deviceId,
                        name:      device.name,
                        image:     device.image,
                        hasLevel:  device.hasLevel,
                        hasTarget: device.hasTarget,
                        // A scene with no actions yet takes its whole room -
                        // so nothing is ticked, and ticking the first device
                        // is what narrows it. Editing a scene that already
                        // names devices ticks exactly those.
                        included:  saved !== undefined,
                        on:        saved !== undefined ? saved.on : device.on,
                        level:     saved !== undefined ? saved.level : device.level,
                        targetC:   saved !== undefined ? saved.targetC : device.targetC,
                    });
                }
                devicesStepRoot.rows = out;
            }

            /*! Rewrite one row. The array is replaced rather than mutated:
                a JS array assigned to a var property does not notify when an
                element changes underneath it, and the delegates would keep
                showing what was there before. */
            function update(index: int, changes: var): void {
                const next = devicesStepRoot.rows.slice();
                const row = {};
                for (const key in next[index])
                    row[key] = next[index][key];
                for (const key in changes)
                    row[key] = changes[key];
                next[index] = row;
                devicesStepRoot.rows = next;
            }

            readonly property int includedCount: {
                let n = 0;
                for (let i = 0; i < devicesStepRoot.rows.length; ++i)
                    n += devicesStepRoot.rows[i].included ? 1 : 0;
                return n;
            }

            readonly property var current:
                devicesStepRoot.rows.length > sceneDeviceList.currentIndex
                && sceneDeviceList.currentIndex >= 0
                    ? devicesStepRoot.rows[sceneDeviceList.currentIndex] : null

            Component.onCompleted: devicesStepRoot.load()

            // The wizard hands its actions back on Save. Set here rather than
            // read by the wizard, so this component owns its own shape and
            // the screen only has to know that a function exists.
            Component.onDestruction: root.pendingActions = devicesStepRoot.rows

            Item {
                id: sceneDevicesHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 56

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StLabel { text: qsTr("Devices"); level: 3 }
                    StLabel {
                        text: devicesStepRoot.includedCount === 0
                              ? qsTr("Nothing picked \u2014 this scene will act on every device in its room")
                              : qsTr("%n device(s) in this scene", "",
                                     devicesStepRoot.includedCount)
                        level: 1
                        tone: "secondary"
                    }
                }
            }

            ListView {
                id: sceneDeviceList

                anchors.left: parent.left
                anchors.top: sceneDevicesHeader.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Theme.spacing4
                width: parent.width * 0.38
                clip: true
                spacing: Theme.spacing3
                currentIndex: 0
                model: devicesStepRoot.rows

                delegate: StCard {
                    id: candidate

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 84
                    interactive: true
                    selected: sceneDeviceList.currentIndex === candidate.index
                    onClicked: sceneDeviceList.currentIndex = candidate.index

                    Image {
                        id: sceneDeviceThumb
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacing4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        source: candidate.modelData.image
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 96
                        smooth: true
                        asynchronous: true
                        opacity: candidate.modelData.included ? 1 : 0.45
                    }

                    Column {
                        anchors.left: sceneDeviceThumb.right
                        anchors.leftMargin: Theme.spacing4
                        anchors.right: includeSwitch.left
                        anchors.rightMargin: Theme.spacing3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        StLabel {
                            width: parent.width
                            text: candidate.modelData.name
                            level: 2
                        }
                        StLabel {
                            width: parent.width
                            text: candidate.modelData.included
                                  ? (candidate.modelData.on ? qsTr("Switch on")
                                                            : qsTr("Switch off"))
                                  : qsTr("Not in this scene")
                            level: 1
                            tone: "secondary"
                        }
                    }

                    StSwitch {
                        id: includeSwitch

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacing4
                        anchors.verticalCenter: parent.verticalCenter
                        accessibleName: qsTr("Include %1").arg(candidate.modelData.name)
                        value: candidate.modelData.included
                        onToggleRequested: next => {
                            devicesStepRoot.update(candidate.index, { included: next });
                            sceneDeviceList.currentIndex = candidate.index;
                        }
                    }
                }
            }

            StCard {
                anchors.left: sceneDeviceList.right
                anchors.right: parent.right
                anchors.top: sceneDeviceList.top
                anchors.leftMargin: Theme.spacing5
                height: panel.implicitHeight + Theme.spacing6 * 2
                visible: devicesStepRoot.current !== null

                Column {
                    id: panel

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing6
                    spacing: 0
                    // Dimmed, not hidden, for a device that is not in the
                    // scene: these are still what WILL be set when it is
                    // added, and hiding them makes the include switch look
                    // like it deletes them.
                    opacity: devicesStepRoot.current !== null
                             && devicesStepRoot.current.included
                                 ? 1 : Theme.disabledOpacity
                    enabled: devicesStepRoot.current !== null
                             && devicesStepRoot.current.included

                    StLabel {
                        width: parent.width
                        text: devicesStepRoot.current === null
                              ? "" : devicesStepRoot.current.name
                        level: 3
                        bottomPadding: Theme.spacing4
                    }

                    // ---- status ------------------------------------------
                    Item {
                        width: parent.width
                        height: 56

                        StLabel {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Status")
                            level: 2
                        }

                        StSwitch {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            trackWidth: 72
                            trackHeight: 38
                            showStateText: true
                            accessibleName: qsTr("Switch on when the scene runs")
                            value: devicesStepRoot.current !== null
                                   && devicesStepRoot.current.on
                            onToggleRequested: next => devicesStepRoot.update(
                                sceneDeviceList.currentIndex, { on: next })
                        }
                    }

                    StDivider {
                        width: parent.width
                        visible: devicesStepRoot.current !== null
                                 && devicesStepRoot.current.hasLevel
                    }

                    // ---- level -------------------------------------------
                    // Brightness, mist, fan speed - the word comes from the
                    // view model, one place, so this screen and the device
                    // page cannot disagree about what a humidifier's slider
                    // is called.
                    Item {
                        width: parent.width
                        height: 76
                        visible: devicesStepRoot.current !== null
                                 && devicesStepRoot.current.hasLevel

                        StLabel {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: devicesStepRoot.current === null ? ""
                                  : root.viewModel.levelLabel(
                                        devicesStepRoot.current.deviceId)
                            level: 2
                        }

                        StSlider {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.62
                            // modelValue, not value: the control writes to
                            // `value` while dragging, which would break a
                            // binding on it after the first drag.
                            modelValue: devicesStepRoot.current === null
                                        || devicesStepRoot.current.level < 0
                                            ? 0 : devicesStepRoot.current.level
                            onMoved: devicesStepRoot.update(
                                sceneDeviceList.currentIndex,
                                { level: Math.round(value) })
                        }
                    }

                    StDivider {
                        width: parent.width
                        visible: devicesStepRoot.current !== null
                                 && devicesStepRoot.current.hasTarget
                    }

                    // ---- thermostat --------------------------------------
                    Item {
                        width: parent.width
                        height: 88
                        visible: devicesStepRoot.current !== null
                                 && devicesStepRoot.current.hasTarget

                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StLabel { text: qsTr("Set temperature"); level: 2 }
                            StLabel {
                                text: qsTr("%1 \u00b0C when this scene runs")
                                        .arg(devicesStepRoot.current === null
                                             || devicesStepRoot.current.targetC < 0
                                                 ? root.viewModel.minTargetC()
                                                 : devicesStepRoot.current.targetC)
                                level: 1
                                tone: "secondary"
                            }
                        }

                        // Stepper, not a dial. The dial on the device page is
                        // a control you hold while watching the room react;
                        // this is a number you set once for later, and two
                        // buttons say that better than a gesture does.
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacing3

                            StIconButton {
                                glyph: "chevronDown"
                                size: 44
                                radius: Theme.radiusSm
                                fill: Theme.surfaceRaised
                                accessibleName: qsTr("Cooler")
                                onClicked: devicesStepRoot.update(
                                    sceneDeviceList.currentIndex,
                                    { targetC: Math.max(
                                        root.viewModel.minTargetC(),
                                        (devicesStepRoot.current.targetC < 0
                                            ? root.viewModel.minTargetC()
                                            : devicesStepRoot.current.targetC) - 1) })
                            }

                            StIconButton {
                                glyph: "chevronUp"
                                size: 44
                                radius: Theme.radiusSm
                                fill: Theme.surfaceRaised
                                accessibleName: qsTr("Warmer")
                                onClicked: devicesStepRoot.update(
                                    sceneDeviceList.currentIndex,
                                    { targetC: Math.min(
                                        root.viewModel.maxTargetC(),
                                        (devicesStepRoot.current.targetC < 0
                                            ? root.viewModel.minTargetC()
                                            : devicesStepRoot.current.targetC) + 1) })
                            }
                        }
                    }

                    StLabel {
                        width: parent.width
                        topPadding: Theme.spacing4
                        // The note that used to be here said these controls
                        // stored nothing, because scenes acted on a room and
                        // there was no scene-to-device table. There is one
                        // now, and this says what it does instead.
                        text: qsTr("Saved with the scene. Ending the scene switches these devices off; it does not put a brightness back, because nothing recorded what it was before.")
                        level: 0
                        tone: "muted"
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                }
            }
        }
    }
}
