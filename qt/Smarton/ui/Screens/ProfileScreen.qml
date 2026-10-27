import QtQuick
import QtQuick.Dialogs
import SmarTon.Backend
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Layouts
import SmarTon.Ui.Components
import SmarTon.Ui.Dialogs

/*!
    \qmltype ProfileScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief Account information, password, notifications, preferences.
           Figma frame 27.

    Only the first tab is editable. Change Password is deliberately a stub
    pointing at the real constraint: changing a password means re-deriving the
    verifier through AuthService, and a form that collects a new password and
    silently drops it is worse than one that says it is not wired.
*/
Item {
    id: root

    /*! smarton::models::AuthViewModel. */
    required property var authViewModel
    /*! smarton::models::ActivityListModel. */
    required property var activityModel
    /*! smarton::models::HomeViewModel. */
    required property var viewModel

    property int tabIndex: 0

    /*! True when the account form differs from the stored record. Drives the
        Save button, so it cannot be pressed on a form that would write back
        exactly what is already there. */
    readonly property bool accountDirty:
        root.tabIndex === 0
        && (draft.fullName !== root.authViewModel.fullName
            || draft.email !== root.authViewModel.email
            || draft.phone !== root.authViewModel.phone)

    /*!
        The account form's in-progress values.

        Held HERE, not in the fields, for the same reason the wizard holds its
        step values: the tab body lives in a Loader, so switching to Change
        Password and back destroys the text fields and everything typed into
        them. It also makes the values reachable from \l accountDirty and
        \l saveAccount, which are outside the Component the fields live in -
        an id inside a Component is not visible from the file around it.
    */
    QtObject {
        id: draft

        property string fullName: root.authViewModel.fullName
        property string email:    root.authViewModel.email
        property string phone:    root.authViewModel.phone
    }

    // After a successful save the stored record IS the draft, so the bindings
    // above re-establish and the form stops reading as dirty. Restated
    // explicitly because typing into a field breaks the binding that seeded
    // it, and a saved form that still says "unsaved" is its own bug.
    /*!
        One place that turns the view model's reports into toasts.

        Per-call checks do not work for everything here: changePassword yields
        to the event loop before it hashes, so reading errorText on the line
        after the call reads the PREVIOUS state. Listening to the properties
        catches the synchronous and asynchronous paths identically, and means
        a new action gets feedback without remembering to add any.
    */
    Connections {
        target: root.authViewModel

        function onErrorTextChanged() {
            // Empty means "cleared", which is not an event worth announcing.
            if (root.authViewModel.errorText.length > 0)
                Notifications.error(root.authViewModel.errorText, "");
        }

        function onStatusTextChanged() {
            if (root.authViewModel.statusText.length > 0)
                Notifications.success(root.authViewModel.statusText, "");
        }

        function onProfileChanged() {
            draft.fullName = root.authViewModel.fullName;
            draft.email    = root.authViewModel.email;
            draft.phone    = root.authViewModel.phone;
        }
    }

    signal backRequested()

    // Declared on the screen, not inside the tab's Component: a Loader
    // destroys the tab body whenever the tab changes, and a FileDialog that
    // dies while it is open takes its callback with it.
    FileDialog {
        id: pictureDialog

        title: qsTr("Choose a profile picture")
        // Filtered by what the build can actually decode, and the store
        // re-checks by CONTENT anyway - an extension filter is a convenience,
        // never a validation.
        nameFilters: [qsTr("Images (*.png *.jpg *.jpeg *.webp *.bmp)")]
        onAccepted: {
            // setAvatar reports through avatarChanged/errorText; the toast is
            // this screen's decision about what that is worth saying.
            // A failure sets errorText and is announced by the Connections
            // block; only the success needs saying here.
            const before = root.authViewModel.errorText;
            root.authViewModel.setAvatar(pictureDialog.selectedFile);
            if (root.authViewModel.errorText === before)
                Notifications.success(qsTr("Profile picture updated"), "");
        }
    }
    FileDialog {
        id: backupDialog

        title: qsTr("Save a backup")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: [qsTr("SmarTon backup (*.json)")]
        onAccepted: {
            if (root.viewModel.exportBackup(backupDialog.selectedFile)) {
                Notifications.success(qsTr("Backup written"),
                                      qsTr("Your house is saved to that file."));
            } else {
                Notifications.error(qsTr("Could not write the backup"),
                                    root.viewModel.lastBackupError);
            }
        }
    }

    FileDialog {
        id: restoreDialog

        title: qsTr("Choose a backup to restore")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("SmarTon backup (*.json)"), qsTr("All files (*)")]
        // Confirmed rather than done: this is the only action in the app that
        // discards everything at once, and a file picker is not a confirmation
        // - people open the wrong file all the time.
        onAccepted: restoreConfirm.open()
    }

    StConfirmDialog {
        id: clearLogConfirm

        parent: root
        title: qsTr("Clear the activity log?")
        message: qsTr("Everything the panel has recorded about this house is "
                      + "discarded. Nothing else changes — your rooms, devices "
                      + "and scenes are untouched.")
        acceptText: qsTr("Clear it")
        rejectText: qsTr("Keep it")
        destructive: true
        onAccepted: {
            root.activityModel.clear();
            Notifications.info(qsTr("Activity log cleared"),
                               qsTr("The panel starts recording again from now."));
        }
    }

    StConfirmDialog {
        id: restoreConfirm

        parent: root
        title: qsTr("Replace everything with this backup?")
        message: qsTr("Your current spaces, rooms, devices, scenes and members "
                      + "are discarded and replaced by what is in that file. "
                      + "This cannot be undone — back up first if you are unsure.")
        acceptText: qsTr("Replace")
        rejectText: qsTr("Cancel")
        destructive: true
        onAccepted: {
            if (root.viewModel.importBackup(restoreDialog.selectedFile)) {
                Notifications.success(qsTr("Backup restored"),
                                      qsTr("The panel is showing the house from that file."));
            } else {
                Notifications.error(qsTr("Could not restore that file"),
                                    root.viewModel.lastBackupError);
            }
        }
    }

    /*!
        Persist the account tab.

        Was a `savePlaceholderRequested` signal that NOTHING connected to, so
        pressing Save did nothing at all and said nothing about it - the worst
        of both, because the fields stayed editable and looked saved.
    */
    function saveAccount(): void {
        // Only the success is raised here. A failure sets errorText, which the
        // Connections block above turns into a toast - saying it twice would
        // stack two overlays describing one event.
        if (root.authViewModel.saveProfile(draft.fullName, draft.email, draft.phone))
            Notifications.success(qsTr("Profile saved"),
                                  qsTr("Your details are stored on this panel."));
    }

    StLabel {
        id: pageTitle

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spacing6
        text: qsTr("Profile")
        level: 3
    }

    StTabBar {
        id: tabs

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: pageTitle.bottom
        anchors.leftMargin: Theme.spacing6
        anchors.rightMargin: Theme.spacing6
        anchors.topMargin: Theme.spacing5
        model: [qsTr("Account information"), qsTr("Change Password"),
                qsTr("Activity"), qsTr("Notifications"), qsTr("Preferences")]
        currentIndex: root.tabIndex
        onSelected: index => root.tabIndex = index
    }

    // Anchored, not placed in a Column: a Loader that computes its height from
    // its own y is a binding loop the first time the content resizes.
    Loader {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tabs.bottom
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing6
        anchors.topMargin: Theme.spacing5
        sourceComponent: root.tabIndex === 0 ? accountTab
                       : root.tabIndex === 1 ? passwordTab
                       : root.tabIndex === 2 ? activityTab
                       : root.tabIndex === 4 ? preferencesTab
                                             : pendingTab
    }

    // ---- bottom action bar --------------------------------------------------
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing6
        anchors.bottomMargin: Theme.spacing5
        height: 84
        radius: Theme.radiusLg
        color: Theme.surfaceDeep
        visible: root.tabIndex === 0

        StLabel {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing6
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Edit your account information")
            level: 1
            tone: "secondary"
        }

        StButton {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing6
            anchors.verticalCenter: parent.verticalCenter
            width: 300
            text: qsTr("Save updates")
            // Disabled while nothing has changed. A Save that is always
            // pressable teaches people to press it and hope; one that greys
            // out is telling them the form and the record already agree.
            enabled: root.accountDirty
            onClicked: root.saveAccount()
        }
    }

    Component {
        id: accountTab

        StScrollView {
            id: accountScroller

            contentHeight: accountColumn.implicitHeight + Theme.spacing8

            Column {
                id: accountColumn

                // Capped and centred, matching the avatar block above it.
                // Full-width fields on a 1600px window give a 1200px-wide box
                // holding a phone number - the eye has to travel the whole
                // width to find a caret, and the form stops reading as a
                // column of related things.
                readonly property int fieldWidth:
                    Math.min(400, accountScroller.width - Theme.spacing6 * 2)

                width: accountScroller.width
                spacing: Theme.spacing4

                // Avatar with an upload affordance. Picking a file needs a
                // file dialog the panel does not have, so the button reports
                // and nothing more.
                Item {
                    width: parent.width
                    height: 180

                    Rectangle {
                        id: avatarRing
                        anchors.centerIn: parent
                        width: 150
                        height: 150
                        radius: width / 2
                        color: Theme.surfaceRaised
                        antialiasing: true

                        StAvatar {
                            anchors.centerIn: parent
                            size: 118
                            // Never empty: the view model falls back to the
                            // bundled picture when the account has none, or
                            // when its file has since been deleted.
                            source: root.authViewModel.avatarSource
                            name: root.authViewModel.currentUserName
                        }
                    }

                    StIconButton {
                        glyph: "image"
                        accessibleName: qsTr("Change profile picture")
                        size: 40
                        radius: 20
                        fill: Theme.textPrimary
                        stroke: Theme.primary
                        anchors.horizontalCenter: avatarRing.horizontalCenter
                        anchors.bottom: avatarRing.bottom
                        onClicked: pictureDialog.open()
                    }

                    StLinkButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: qsTr("Remove picture")
                        visible: root.authViewModel.hasCustomAvatar
                        onClicked: {
                            root.authViewModel.clearAvatar();
                            Notifications.info(qsTr("Profile picture removed"),
                                               qsTr("Back to the default image."));
                        }
                    }
                }

                StFormField {
                    width: accountColumn.fieldWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    label: qsTr("Full Name")
                    StTextField {
                        id: fullName
                        width: parent.width
                        // The stored display name, not the username. These
                        // were both bound to currentUserName, which is why
                        // "Full Name" and "Email" showed the same thing.
                        text: draft.fullName
                        onTextChanged: draft.fullName = fullName.text
                    }
                }

                StFormField {
                    width: accountColumn.fieldWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    label: qsTr("Phone")
                    StTextField {
                        id: phone
                        width: parent.width
                        text: draft.phone
                        onTextChanged: draft.phone = phone.text
                        placeholderText: qsTr("+00 00 00 0000")
                        inputMethodHints: Qt.ImhDialableCharactersOnly
                    }
                }

                StFormField {
                    width: accountColumn.fieldWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    label: qsTr("Email")
                    StTextField {
                        id: email
                        width: parent.width
                        text: draft.email
                        onTextChanged: draft.email = email.text
                        placeholderText: qsTr("you@example.com")
                        // Checked as you type, saved on Save. Marking it in
                        // place beats a toast on submit: the field that is
                        // wrong is the one that should say so.
                        errorText: email.text.length > 0
                                   && !root.authViewModel.isPlausibleEmail(email.text)
                                   ? qsTr("That does not look like an email address.")
                                   : ""
                        inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
                    }
                }

                Item { width: 1; height: 100 }   // clears the action bar
            }
        }
    }

    // ---- tab 2: change password --------------------------------------------
    Component {
        id: passwordTab

        Item {
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacing6
                width: Math.min(parent.width, Theme.fieldWidth)
                spacing: Theme.spacing4

                StLabel {
                    width: parent.width
                    text: qsTr("Changing your password signs you out of nothing else — "
                               + "there is one session on this panel. The new password "
                               + "is hashed with the current parameters, so a change is "
                               + "also an upgrade.")
                    level: 1
                    tone: "secondary"
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }

                StLabel { text: qsTr("Current password"); level: 1; tone: "secondary" }

                StTextField {
                    id: currentPassword
                    width: parent.width
                    password: true
                    enabled: !root.authViewModel.busy
                    KeyNavigation.tab: newPassword
                    onTextChanged: root.authViewModel.clearError()
                }

                StLabel { text: qsTr("New password"); level: 1; tone: "secondary" }

                StTextField {
                    id: newPassword
                    width: parent.width
                    password: true
                    enabled: !root.authViewModel.busy
                    KeyNavigation.tab: confirmPassword
                    KeyNavigation.backtab: currentPassword
                    onTextChanged: root.authViewModel.clearError()
                }

                // The same rules the service enforces. If these ever disagree
                // the form green-ticks a password the backend then rejects.
                StPasswordRules {
                    id: newPasswordRules
                    width: parent.width
                    password: newPassword.text
                }

                StLabel { text: qsTr("Confirm new password"); level: 1; tone: "secondary" }

                StTextField {
                    id: confirmPassword
                    width: parent.width
                    password: true
                    enabled: !root.authViewModel.busy
                    KeyNavigation.tab: changeButton
                    KeyNavigation.backtab: newPassword
                    errorText: confirmPassword.text.length > 0
                               && confirmPassword.text !== newPassword.text
                               ? qsTr("Passwords do not match") : ""
                    onTextChanged: root.authViewModel.clearError()
                }

                Item { width: 1; height: Theme.spacing2 }

                StLabel {
                    width: parent.width
                    text: root.authViewModel.errorText
                    level: 1
                    color: Theme.danger
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    visible: root.authViewModel.errorText.length > 0
                }

                StLabel {
                    width: parent.width
                    text: root.authViewModel.statusText
                    level: 1
                    color: Theme.success
                    visible: root.authViewModel.statusText.length > 0
                }

                StButton {
                    id: changeButton

                    width: parent.width
                    KeyNavigation.backtab: confirmPassword
                    text: root.authViewModel.busy ? qsTr("Updating…")
                                                  : qsTr("Update password")
                    enabled: !root.authViewModel.busy
                             && currentPassword.text.length > 0
                             && newPasswordRules.acceptable
                             && newPassword.text === confirmPassword.text
                    onClicked: {
                        root.authViewModel.changePassword(currentPassword.text,
                                                          newPassword.text,
                                                          confirmPassword.text);
                        // Cleared immediately either way: a plaintext password
                        // left sitting in a visible field on an unattended
                        // panel is the thing the idle lock exists to prevent.
                        currentPassword.text = "";
                        newPassword.text = "";
                        confirmPassword.text = "";
                    }
                }
            }
        }
    }

    /*!
        What happened in the house, newest first.

        In Profile rather than the sidebar. The five sidebar destinations are
        the design's and adding a sixth is a change to a frame nobody drew; a
        log is also something you go and look at once, when something
        surprised you, rather than somewhere you live.
    */
    Component {
        id: activityTab

        Item {
            StLabel {
                id: activityTitle

                anchors.left: parent.left
                anchors.top: parent.top
                text: qsTr("What happened here")
                level: 3
            }

            StLabel {
                id: activityHint

                anchors.left: parent.left
                anchors.right: clearButton.left
                anchors.rightMargin: Theme.spacing4
                anchors.top: activityTitle.bottom
                anchors.topMargin: Theme.spacing2
                text: qsTr("Every switch, every scene, every sign-in — with who did it. The house acting on its own schedule has no name against it, because attributing that to whoever happened to be signed in would be a lie in the one record you read to find out what happened.")
                level: 1
                tone: "secondary"
                wrapMode: Text.WordWrap
            }

            StButton {
                id: clearButton

                anchors.right: parent.right
                anchors.top: parent.top
                width: 180
                variant: "secondary"
                iconName: "trash"
                text: qsTr("Clear the log")
                // Administration: a log somebody can quietly empty is not a
                // log. Selling the panel or handing it to a tenant is the
                // case this exists for.
                visible: root.viewModel.canAdminister
                         && root.activityModel.rowCount() > 0
                onClicked: clearLogConfirm.open()
            }

            ListView {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: activityHint.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Theme.spacing5
                clip: true
                spacing: 0
                model: root.activityModel

                delegate: Item {
                    id: line

                    required property var model
                    required property int index

                    width: ListView.view.width
                    height: 64

                    Rectangle {
                        id: kindDot

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        // By KIND, not by good/bad. A log has no opinion about
                        // whether a light going off was welcome.
                        color: line.model.kind === "scene"   ? Theme.info
                             : line.model.kind === "session" ? Theme.warning
                             : line.model.bySystem           ? Theme.textMuted
                                                             : Theme.primary
                    }

                    Column {
                        anchors.left: kindDot.right
                        anchors.leftMargin: Theme.spacing4
                        anchors.right: whenLabel.left
                        anchors.rightMargin: Theme.spacing4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        StLabel {
                            width: parent.width
                            text: qsTr("%1 %2").arg(line.model.subject)
                                               .arg(line.model.detail)
                            level: 2
                        }

                        StLabel {
                            width: parent.width
                            text: line.model.bySystem
                                  ? qsTr("by the panel")
                                  : qsTr("by %1").arg(line.model.actor)
                            level: 0
                            tone: "muted"
                        }
                    }

                    StLabel {
                        id: whenLabel

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.model.whenText
                        level: 1
                        tone: "secondary"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Theme.outline
                        opacity: 0.35
                    }
                }
            }

            StEmptyState {
                anchors.fill: parent
                visible: root.activityModel.rowCount() === 0
                title: qsTr("Nothing has happened yet.")
                detail: qsTr("Switch something on, or wait for a scene to run, and it appears here.")
                imageSource: "qrc:/qt/qml/SmarTon/Resources/images/illustrations/smart-home.png"
                imageSize: 200
            }
        }
    }

    Component {
        id: pendingTab

        StEmptyState {
            title: qsTr("Notification settings are not built yet.")
            detail: qsTr("SmarTon has no notification channel — no mail transport and no push service — so there is nothing here to configure yet.")
        }
    }

    Component {
        id: preferencesTab

        StScrollView {
            id: preferencesScroller

            contentHeight: preferencesColumn.implicitHeight + Theme.spacing8

            Column {
                id: preferencesColumn

                // Minus the scrollbar's lane: this column is the tallest
                // content in the screen, so it always has a bar, and a Flow
                // sized to the full width would tuck its last swatch under it.
                width: preferencesScroller.width - Theme.scrollBarWidth - Theme.spacing2
                spacing: Theme.spacing6

                // ---- theme ----------------------------------------------
                Column {
                    width: parent.width
                    spacing: Theme.spacing3

                    StLabel { text: qsTr("Appearance"); level: 2
                              font.weight: Theme.fontWeightMedium }
                    StLabel {
                        width: parent.width
                        text: qsTr("Two skins over the same design tokens. Measured is the panel's reference treatment, checked against the source design; Glass is translucent surfaces over a lit backdrop.")
                        level: 1
                        tone: "secondary"
                        wrapMode: Text.WordWrap
                    }

                    StSegmentedControl {
                        model: [qsTr("Measured"), qsTr("Glass")]
                        currentIndex: Appearance.glassTheme ? 1 : 0
                        onSelected: index => Appearance.setThemeName(
                                        index === 1 ? "glass" : "figma")
                    }
                }

                // ---- render quality --------------------------------------
                Column {
                    width: parent.width
                    spacing: Theme.spacing3
                    // Only worth showing when there is something to spend it
                    // on. Under the measured theme every tier looks identical.
                    visible: Appearance.glassTheme

                    StLabel { text: qsTr("Visual effects"); level: 2
                              font.weight: Theme.fontWeightMedium }
                    StLabel {
                        width: parent.width
                        text: qsTr("Backdrop blur and drifting particles are the most expensive things on screen. This is detected from the hardware at first run — lower it if the interface feels less than smooth, and nothing but the decoration is lost.")
                        level: 1
                        tone: "secondary"
                        wrapMode: Text.WordWrap
                    }

                    StSegmentedControl {
                        model: [qsTr("Plain"), qsTr("Balanced"), qsTr("Full")]
                        currentIndex: Appearance.renderTier
                        onSelected: index => Appearance.setRenderTier(index)
                    }

                    StLabel {
                        width: parent.width
                        text: Appearance.renderTier >= 2
                              ? qsTr("Blur and particles on.")
                              : Appearance.renderTier === 1
                                ? qsTr("Gradients and glow; no blur or particles.")
                                : qsTr("Flat surfaces. Cheapest to draw.")
                        level: 0
                        tone: "muted"
                    }
                }

                // ---- shadows ---------------------------------------------
                // Its own control, not part of the tier. A tier is decoration
                // you lose nothing by dropping; a shadow is a GPU blur pass
                // per elevated tile, a dozen of them on a dashboard, and the
                // largest single item on the panel's frame budget. Somebody
                // may well want the glass theme's gradients without it.
                Column {
                    width: parent.width
                    spacing: Theme.spacing3

                    StLabel { text: qsTr("Tile shadows"); level: 2
                              font.weight: Theme.fontWeightMedium }
                    StLabel {
                        width: parent.width
                        text: qsTr("Each raised tile is drawn over a blurred copy of itself. It is the most expensive thing on a busy screen and it carries no information — turn it off and the tiles keep their borders and read exactly the same.")
                        level: 1
                        tone: "secondary"
                        wrapMode: Text.WordWrap
                    }

                    StSwitch {
                        trackWidth: 72
                        trackHeight: 38
                        showStateText: true
                        accessibleName: qsTr("Tile shadows")
                        value: Appearance.shadowsEnabled
                        onToggleRequested: requested =>
                            Appearance.setShadowsEnabled(requested)
                    }
                }

                StDivider { width: parent.width }

                // ---- accent ---------------------------------------------
                Column {
                    width: parent.width
                    spacing: Theme.spacing2

                    StLabel { text: qsTr("Accent colour"); level: 2
                              font.weight: Theme.fontWeightMedium }
                    StLabel {
                        width: parent.width
                        text: qsTr("Applies everywhere the interface highlights something \u2014 buttons, switches, the selected tab. Surfaces and text are not adjustable: their contrast against each other is what keeps the panel readable at arm's length.")
                        level: 1
                        tone: "secondary"
                        wrapMode: Text.WordWrap
                    }
                }

                StCard {
                    width: parent.width
                    implicitHeight: swatchArea.implicitHeight + Theme.spacing6 * 2

                    Column {
                        id: swatchArea

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacing6
                        spacing: Theme.spacing5

                        Flow {
                            width: parent.width
                            spacing: Theme.spacing4

                            Repeater {
                                model: Appearance.accentPresets

                                delegate: Rectangle {
                                    id: swatch

                                    required property var modelData

                                    readonly property bool current:
                                        Qt.colorEqual(swatch.modelData.color,
                                                      Appearance.accentColor)

                                    width: 92
                                    height: 64
                                    radius: Theme.radiusSm
                                    color: swatch.modelData.color

                                    // The ring is drawn OUTSIDE the fill rather
                                    // than as a border, because a border eats
                                    // into the swatch and makes the selected
                                    // colour read as a smaller sample than the
                                    // others - which is exactly the comparison
                                    // this grid exists to support.
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width + 8
                                        height: parent.height + 8
                                        radius: parent.radius + 4
                                        color: "transparent"
                                        border.width: Theme.borderWidthFocus
                                        border.color: swatch.current ? Theme.textPrimary
                                                    : hover.hovered  ? Theme.outlineStrong
                                                                     : "transparent"

                                        Behavior on border.color {
                                            ColorAnimation { duration: Theme.durationFast }
                                        }
                                    }

                                    StIcon {
                                        anchors.centerIn: parent
                                        name: "check"
                                        size: 20
                                        // Measured against THIS swatch, not
                                        // against the accent: a tick that is
                                        // white on Mint is invisible.
                                        color: swatch.modelData.foreground
                                        visible: swatch.current
                                    }

                                    Accessible.role: Accessible.RadioButton
                                    Accessible.name: swatch.modelData.name
                                    Accessible.checked: swatch.current
                                    Accessible.onPressAction: Appearance.setAccentColor(
                                                                  swatch.modelData.color)

                                    HoverHandler { id: hover }
                                    TapHandler {
                                        onTapped: Appearance.setAccentColor(
                                                      swatch.modelData.color)
                                    }
                                }
                            }
                        }

                        StDivider { width: parent.width }

                        // ---- custom -------------------------------------
                        Row {
                            width: parent.width
                            spacing: Theme.spacing4

                            StFormField {
                                width: 220
                                label: qsTr("Custom (hex)")

                                StTextField {
                                    id: customAccent

                                    width: parent.width
                                    placeholderText: qsTr("#E25319")
                                    text: Appearance.usingDefaultAccent
                                          ? "" : String(Appearance.accentColor)
                                    // Refused rather than clamped, and the
                                    // reason is shown: silently substituting a
                                    // nearby legal colour would leave someone
                                    // convinced the field is broken.
                                    errorText: customAccent.text.length > 0
                                               && !Appearance.isAcceptableAccentName(customAccent.text)
                                               ? qsTr("Too close to the background, or nothing reads on it.")
                                               : ""
                                    onAccepted: Appearance.setAccentColorName(customAccent.text)
                                }
                            }

                            StButton {
                                anchors.bottom: parent.bottom
                                text: qsTr("Apply")
                                variant: "secondary"
                                enabled: Appearance.isAcceptableAccentName(customAccent.text)
                                onClicked: Appearance.setAccentColorName(customAccent.text)
                            }

                            StButton {
                                anchors.bottom: parent.bottom
                                text: qsTr("Reset to default")
                                variant: "ghost"
                                enabled: !Appearance.usingDefaultAccent
                                onClicked: {
                                    Appearance.resetAccentColor();
                                    customAccent.text = "";
                                }
                            }
                        }
                    }
                }

                // ---- live preview -------------------------------------------
                Column {
                    width: parent.width
                    spacing: Theme.spacing3

                    StLabel { text: qsTr("Preview"); level: 2
                              font.weight: Theme.fontWeightMedium }
                    StLabel {
                        width: parent.width
                        text: qsTr("Real controls, not a picture of them \u2014 they are bound to the same token the rest of the app is, so what you see here is what ships.")
                        level: 1
                        tone: "secondary"
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        spacing: Theme.spacing4

                        StButton { text: qsTr("Primary"); width: 150 }
                        StButton { text: qsTr("Secondary"); variant: "secondary"; width: 150 }
                        StSwitch {
                            anchors.verticalCenter: parent.verticalCenter
                            value: true
                            showStateText: true
                        }
                        StCheckBox {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Checked")
                            checked: true
                        }
                    }
                }

                StDivider { width: parent.width }

                // ---- backup and restore -------------------------------------
                Column {
                    width: parent.width
                    spacing: Theme.spacing3
                    // Administration, and the most consequential thing on this
                    // tab: restoring replaces the house. A Viewer who can see
                    // the button cannot use it, so they do not see it.
                    visible: root.viewModel.canAdminister

                    StLabel { text: qsTr("Backup"); level: 2
                              font.weight: Theme.fontWeightMedium }
                    StLabel {
                        width: parent.width
                        text: qsTr("Writes your spaces, rooms, devices, scenes and members to one file. Accounts and passwords are NOT included — a backup is a file people carry around on a USB stick, and password verifiers are not something to carry around. Members keep their link to an account, so a restore onto this panel finds them again.")
                        level: 1
                        tone: "secondary"
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        spacing: Theme.spacing3

                        StButton {
                            width: 220
                            variant: "secondary"
                            text: qsTr("Back up now")
                            onClicked: {
                                // Preselect a dated name so two backups in one
                                // week do not overwrite each other by default.
                                // Only when the dialog already has a folder -
                                // concatenating onto an empty URL produces a
                                // path at the filesystem root.
                                const folder = backupDialog.currentFolder.toString();
                                if (folder.length > 0) {
                                    backupDialog.selectedFile =
                                        folder + "/" + root.viewModel.suggestedBackupName();
                                }
                                backupDialog.open();
                            }
                        }

                        StButton {
                            width: 220
                            variant: "secondary"
                            text: qsTr("Restore…")
                            onClicked: restoreDialog.open()
                        }
                    }
                }

                StDivider { width: parent.width; visible: root.viewModel.canAdminister }

                // ---- not wired yet ------------------------------------------
                Column {
                    width: parent.width
                    spacing: Theme.spacing2

                    StLabel { text: qsTr("This build"); level: 2
                              font.weight: Theme.fontWeightMedium }
                    StLabel {
                        width: parent.width
                        // Decided at configure time, where nobody can see it.
                        text: Capabilities.mqttTransport
                              ? qsTr("Devices can be reached through an MQTT broker — start the panel with --transport mqtt://host. Without it, the panel runs against its built-in simulator.")
                              : qsTr("This build has no MQTT support, so devices run against the built-in simulator. Rebuilding with Qt MQTT installed enables --transport mqtt://host.")
                        level: 1
                        tone: "secondary"
                        wrapMode: Text.WordWrap
                    }

                    Item { width: 1; height: Theme.spacing3 }

                    StLabel { text: qsTr("Auto-lock"); level: 2
                              font.weight: Theme.fontWeightMedium }
                    StLabel {
                        width: parent.width
                        text: qsTr("A wall panel is not a laptop: it sits unattended in a hallway and anyone walking past inherits the session. After this long without a touch, the panel locks and asks for a password again.")
                        level: 1
                        tone: "secondary"
                        wrapMode: Text.WordWrap
                    }

                    StSegmentedControl {
                        // Fixed choices, not a number field. "How long before
                        // the hallway panel locks" has about four sensible
                        // answers and a text box invites the fifth.
                        model: [qsTr("Never"), qsTr("1 min"), qsTr("5 min"),
                                qsTr("15 min"), qsTr("30 min")]
                        currentIndex: {
                            const seconds = root.authViewModel.idleLockSeconds;
                            if (seconds <= 0)   return 0;
                            if (seconds <= 60)  return 1;
                            if (seconds <= 300) return 2;
                            if (seconds <= 900) return 3;
                            return 4;
                        }
                        onSelected: index => {
                            const seconds = [0, 60, 300, 900, 1800][index];
                            root.authViewModel.setIdleLockSeconds(seconds);
                            Notifications.success(
                                seconds === 0 ? qsTr("Auto-lock off")
                                              : qsTr("Auto-lock set"),
                                seconds === 0
                                    ? qsTr("The panel stays signed in until you log out.")
                                    : qsTr("The panel locks after %1 without a touch.")
                                        .arg(seconds >= 60
                                             ? qsTr("%1 minutes").arg(Math.round(seconds / 60))
                                             : qsTr("%1 seconds").arg(seconds)));
                        }
                    }

                    Item { width: 1; height: Theme.spacing3 }

                    StLabel { text: qsTr("Language"); level: 2
                              font.weight: Theme.fontWeightMedium }
                    StLabel {
                        width: parent.width
                        text: qsTr("Still a command-line option (--lang). A language switch has to reload every string in the running interface, which is a different piece of work from storing the choice — listed here rather than shown as a control that stores a preference nothing reads.")
                        level: 1
                        tone: "secondary"
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    /*! Caption above a field. The design labels every input. */
    component StFormField: Column {
        id: formField

        property string label: ""

        spacing: Theme.spacing2

        StLabel {
            text: formField.label
            level: 1
            tone: "secondary"
            font.weight: Theme.fontWeightMedium
        }
    }
}
