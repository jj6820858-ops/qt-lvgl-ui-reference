import QtQuick
import QtQuick.Controls.Basic as QQC
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme
import SmarTon.Ui.Navigation
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components

/*!
    \qmltype ShellScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief The signed-in application frame: persistent sidebar + page stack.

    NAVIGATION MODEL. There are two StackViews in SmarTon and they answer two
    different questions.

    \list
    \li The one in \c Main.qml switches between the pre-login flow and this
        shell. Signing in REPLACES the flow rather than pushing onto it, so
        there is no back path from the app into a login screen.
    \li The one here is the shell's own stack. A sidebar entry \c replaces the
        stack, because the five destinations are siblings and "back" between
        siblings is meaningless. Drilling in - Rooms into a room, a room into
        a device - \c pushes, so Escape and the header back arrow pop exactly
        one level.
    \endlist

    The shell owns \l currentRoute; the sidebar renders whatever it is given
    and reports taps. That split is what lets the sidebar be tested with no
    stack behind it, and lets a deep link set the route without faking a tap.
*/
Item {
    id: root

    /*! smarton::models::AuthViewModel. */
    required property var viewModel
    /*! smarton::models::HomeViewModel. */
    required property var homeViewModel
    /*! smarton::models::ActivityListModel. Passed through to Profile rather
        than given a sidebar entry of its own: the five destinations are the
        design's, and a log is something you go and look at, not somewhere you
        live. */
    required property var activityModel

    /*! Which sidebar entry is lit. Setting it does NOT navigate - call go(). */
    property string currentRoute: Routes.spaces

    /*! Restored rail width, or 0 for the design default. Already clamped by
        the preferences layer - the settings file is hand-editable. */
    property int initialSidebarWidth: 0
    /*! The live width, for the composition root to store on the way out.
        Read rather than written back through a binding, because SplitView
        owns the handle position while the user is dragging it. */
    readonly property int currentSidebarWidth: Math.round(sidebar.width)

    signal logoutRequested()

    /*!
        The two ways a change can fail after the UI has already accepted it,
        said out loud exactly once, here.

        Both were silent before. A command the transport could not deliver
        left the switch pending forever with no explanation, and a change
        refused by the signed-in role did nothing at all - and "nothing
        happened" is the least useful thing an interface can do. One handler
        at the shell rather than one per screen: there is nothing
        screen-specific about either message, and the screen that forgets to
        listen is the one where it matters.
    */
    Connections {
        target: root.homeViewModel

        function onCommandFailed(deviceId, deviceName) {
            Notifications.warning(qsTr("%1 did not answer").arg(deviceName),
                                  qsTr("The command was sent but never confirmed. "
                                       + "The panel is showing what the device last reported."));
        }

        function onPermissionDenied(action) {
            // The service sends a KEY, not a sentence: it does not know the
            // user's language and should not be composing prose.
            Notifications.warning(
                action === "administer" ? qsTr("Owners and administrators only")
                : action === "install" ? qsTr("Installers only")
                : qsTr("You cannot change devices"),
                action === "administer"
                    ? qsTr("Your account can use this space but not change what is in it.")
                    : qsTr("Your account can see this space but not operate it."));
        }

        function onDeviceReachabilityChanged(deviceId, deviceName, online) {
            if (online) {
                Notifications.info(qsTr("%1 is back online").arg(deviceName),
                                   qsTr("Its reported state is available again."));
            } else {
                Notifications.warning(qsTr("%1 is not responding").arg(deviceName),
                                      qsTr("The panel will retain its last reported state."));
            }
        }
    }

    // A life-safety event is intentionally not a toast: toasts time out and
    // can be covered by another notification. The adapter reports an active
    // sensor as ON; this band stays until the hardware reports it clear.
    Rectangle {
        id: safetyAlarmBand
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: visible ? 82 : 0
        visible: root.homeViewModel.criticalAlerts.length > 0
        z: 1000
        color: Theme.danger

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing6
            anchors.rightMargin: Theme.spacing6
            spacing: Theme.spacing4

            StLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("SAFETY ALERT")
                level: 2
                color: "white"
            }
            Repeater {
                model: root.homeViewModel.criticalAlerts
                delegate: StButton {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name + qsTr(" — active")
                    variant: "secondary"
                    onClicked: root.openDevice(modelData.deviceId)
                }
            }
        }
    }

    /*! Switch destination. Idempotent: re-tapping the current entry unwinds
        any drill-down instead of stacking a second copy of the same page. */
    function go(route: string): void {
        if (route === root.currentRoute && pages.depth === 1)
            return;
        root.currentRoute = route;
        pages.replace(null, root._componentFor(route));
    }

    /*!
        Drill one level deeper without changing the lit sidebar entry.

        Both parameters and the return type are annotated. Qt 6.8 warns when an
        unannotated function's result is handed to an annotated one - it has to
        assume `void` and keep the value anyway, and says so on every call. A
        future Qt will drop the value instead, at which point every push here
        would silently do nothing.
    */
    function push(component: Component, properties: var): void {
        pages.push(component, properties === undefined ? {} : properties);
    }

    /*! Open a room's detail. The id is passed, never the record - see
        RoomOverviewScreen for why a copy would go stale. */
    function openRoom(roomId: string): void {
        root.push(roomOverviewPage, { roomId: roomId });
    }

    function openDevice(deviceId: string): void {
        root.push(deviceDetailPage, { deviceId: deviceId });
    }

    /*! Frame 09: the plan and every device under it. Pushed from the Spaces
        dashboard's map card, so the lit sidebar entry stays on Spaces. */
    function openSpaceMap(): void {
        root.push(mapViewPage, {});
    }

    /*! The customise step for a device being linked. Frame 11. */
    function openLinkDevice(availableId: string): void {
        root.push(linkDevicePage, { availableId: availableId });
    }

    /*! The space wizard. Its steps commit as they go, so leaving it early
        keeps whatever was already created - see SpaceWizardScreen. */
    function openSpaceWizard(): void {
        root.push(spaceWizardPage, {});
    }

    /*! Empty sceneId creates; a real one edits that scene. */
    function openSceneWizard(sceneId: string): void {
        root.push(sceneWizardPage, { sceneId: sceneId });
    }

    function back(): void {
        if (pages.depth > 1)
            pages.pop();
    }

    function _componentFor(route: string): Component {
        switch (route) {
        case Routes.rooms:      return roomsPage;
        case Routes.devices:    return devicesPage;
        case Routes.members:    return membersPage;
        case Routes.statistics: return statisticsPage;
        case Routes.operations: return operationsPage;
        case Routes.settings:   return settingsPage;
        default:                return spacesPage;
        }
    }

    /*!
        The page backdrop, and what every glass surface in the shell frosts.

        ONE instance for the whole shell, below everything. A backdrop per
        screen would mean the aurora restarting on every navigation - the
        blobs snapping back to their start positions, which reads as a flicker
        - and it would mean N particle systems where one is plenty.

        In the Figma theme this is just \c Theme.background, so it costs
        nothing and there is no second code path to keep in step.
    */
    StAurora {
        id: backdrop
        anchors.fill: parent
    }

    /*! Sidebar width, in px. Persisted by the shell's owner. */
    property alias sidebarWidth: sidebar.width

    QQC.SplitView {
        id: split

        anchors.fill: parent
        orientation: Qt.Horizontal

        // A thin, deliberately quiet handle. It widens and lights up on hover
        // so it is discoverable, but at rest it reads as the 1 px seam the
        // design draws rather than as a control competing with the nav.
        handle: Rectangle {
            implicitWidth: 6
            implicitHeight: split.height
            color: "transparent"

            Rectangle {
                anchors.centerIn: parent
                width: parent.QQC.SplitHandle.pressed ? 2
                     : parent.QQC.SplitHandle.hovered ? 2 : 1
                height: parent.height
                color: parent.QQC.SplitHandle.pressed  ? Theme.primary
                     : parent.QQC.SplitHandle.hovered  ? Theme.outlineStrong
                                                       : Theme.surfaceRaised

                Behavior on width { NumberAnimation { duration: Theme.durationFast } }
                Behavior on color { ColorAnimation  { duration: Theme.durationFast } }
            }
        }

        StSidebar {
            id: sidebar

            // Bounds, not a fixed width. The floor is where "Profile &
            // Settings" starts to elide; the ceiling is where the rail stops
            // being a rail and starts eating the content it exists to serve.
            // On a 1024 panel a 320 px sidebar leaves 698 for a three-column
            // grid, which is already tight.
            // preferredWidth is read ONCE, when the SplitView first lays out,
            // and the user's drag then owns it - so this is an initial value,
            // not a binding to keep live. Writing to it during a drag would
            // fight the handle.
            QQC.SplitView.preferredWidth: root.initialSidebarWidth > 0
                                          ? root.initialSidebarWidth
                                          : Theme.sidebarWidth
            QQC.SplitView.minimumWidth: Theme.sidebarMinWidth
            QQC.SplitView.maximumWidth: Theme.sidebarMaxWidth
            QQC.SplitView.fillWidth: false

            model: Routes.navigation
            currentRoute: root.currentRoute
            userName: root.viewModel.currentUserName
            avatarSource: root.viewModel.avatarSource
            onNavigate: route => root.go(route)
            onSettingsRequested: root.go(Routes.settings)
            onLogoutRequested: root.logoutRequested()
        }

    QQC.StackView {
        id: pages

        QQC.SplitView.fillWidth: true
        QQC.SplitView.minimumWidth: 560
        initialItem: spacesPage

        // Every screen arrives ready to type. Done here rather than in each
        // screen because "where does focus start" is a property of NAVIGATION,
        // not of a screen - and left to the screens it was answered by exactly
        // one of them.
        //
        // Deferred by a tick: currentItem changes when the incoming screen is
        // created, and its own children - the Loaders inside the wizards above
        // all - are not populated until the frame after. Searching immediately
        // finds an empty tree and focuses nothing.
        onCurrentItemChanged: focusTimer.restart()

        Timer {
            id: focusTimer
            interval: 0
            onTriggered: {
                if (pages.currentItem !== null)
                    FocusHelper.focusFirstField(pages.currentItem);
            }
        }

        // Transitions off. A cross-fade between two full screens on the panel
        // costs a composited layer per side for the length of the animation,
        // and on the RK3328 that is visible as a hitch on exactly the action
        // that should feel instant. Assigned null rather than deleted so the
        // decision is visible and reversible in one place.
        pushEnter: null
        pushExit: null
        popEnter: null
        popExit: null
        replaceEnter: null
        replaceExit: null
    }
    }

    // Escape pops one drill-down level. Deliberately does NOT log out.
    Keys.onEscapePressed: function (event) {
        if (pages.depth > 1) {
            pages.pop();
            event.accepted = true;
        }
    }

    // ---- destinations ----------------------------------------------------
    // Components, not Loaders: a destination is built when it is first shown
    // and destroyed when it is replaced, so five screens' worth of delegates
    // are never alive at once on a panel with this much GPU memory.

    Component {
        id: spacesPage
        SpacesScreen {
            viewModel: root.homeViewModel
            onSetUpSpaceRequested: root.openSpaceWizard()
            onRoomRequested: roomId => root.openRoom(roomId)
            onDeviceRequested: deviceId => root.openDevice(deviceId)
            onMembersRequested: root.go(Routes.members)
            onSpaceMapRequested: root.openSpaceMap()
            onAddSpaceRequested: root.openSpaceWizard()
        }
    }

    Component {
        id: roomsPage
        RoomsScreen {
            viewModel: root.homeViewModel
            onAddSpaceRequested: root.openSpaceWizard()
            onRoomRequested: roomId => root.openRoom(roomId)
            onEditRoomRequested: roomId => root.openRoom(roomId)
            onDeviceRequested: deviceId => root.openDevice(deviceId)
            onAddRoomRequested: root.openSpaceWizard()
        }
    }

    Component {
        id: devicesPage
        ScenariosScreen {
            viewModel: root.homeViewModel
            onBackRequested: root.back()
            onAddSceneRequested: root.openSceneWizard("")
            onEditSceneRequested: sceneId => root.openSceneWizard(sceneId)
        }
    }

    Component {
        id: membersPage
        MembersScreen {
            viewModel: root.homeViewModel
            authViewModel: root.viewModel
            onBackRequested: root.back()
        }
    }

    Component {
        id: statisticsPage
        StatisticsScreen {
            viewModel: root.homeViewModel
            onBackRequested: root.back()
            onRoomRequested: roomId => root.openRoom(roomId)
        }
    }

    Component {
        id: operationsPage
        OperationsScreen {
            viewModel: root.homeViewModel
            onDeviceRequested: deviceId => root.openDevice(deviceId)
        }
    }

    Component {
        id: settingsPage
        ProfileScreen {
            viewModel: root.homeViewModel
            authViewModel: root.viewModel
            activityModel: root.activityModel
            onBackRequested: root.back()
        }
    }

    // ---- drill-downs -------------------------------------------------------
    // Pushed, not replaced: these have a parent to go back to, and the lit
    // sidebar entry stays where it was.

    Component {
        id: roomOverviewPage
        RoomOverviewScreen {
            viewModel: root.homeViewModel
            onBackRequested: root.back()
            onDeviceRequested: deviceId => root.openDevice(deviceId)
        }
    }

    Component {
        id: deviceDetailPage
        DeviceDetailScreen {
            viewModel: root.homeViewModel
            onAddSpaceRequested: root.openSpaceWizard()
            onBackRequested: root.back()
        }
    }

    Component {
        id: mapViewPage
        MapViewScreen {
            viewModel: root.homeViewModel
            onAddSpaceRequested: root.openSpaceWizard()
            onBackRequested: root.back()
            onRoomRequested: roomId => root.openRoom(roomId)
            onDeviceRequested: deviceId => root.openDevice(deviceId)
            onAddRoomRequested: root.openSpaceWizard()
            // Unwinds to the Rooms destination rather than pushing a second
            // room list on top of this one - the two are siblings, not a
            // drill-down.
            onRoomsRequested: root.go(Routes.rooms)
        }
    }

    Component {
        id: spaceWizardPage
        SpaceWizardScreen {
            viewModel: root.homeViewModel
            onFinished: root.back()
            onCancelled: root.back()
            onCustomiseDeviceRequested: availableId =>
                root.openLinkDevice(availableId)
        }
    }

    Component {
        id: linkDevicePage
        LinkDeviceScreen {
            viewModel: root.homeViewModel
            onFinished: root.back()
            onCancelled: root.back()
        }
    }

    Component {
        id: sceneWizardPage
        SceneWizardScreen {
            viewModel: root.homeViewModel
            onFinished: root.back()
            onCancelled: root.back()
        }
    }
}
