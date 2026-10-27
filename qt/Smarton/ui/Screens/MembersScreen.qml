import QtQuick
import QtQuick.Controls.Basic as QQC
import QtQuick.Dialogs
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Components

/*!
    \qmltype MembersScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief The household. Reached from the sidebar and the dashboard card.

    The design set has no dedicated Members frame - members appear on the
    dashboard (07) and in the wizard's confirm step (17) - so this reuses
    those two treatments rather than inventing a third: the summary header
    from the wizard, and the wizard's member rows.

    Members are LOCAL RECORDS. There is no invitation, no account, no
    permission model behind them: SmarTon authenticates one operator against
    a local password. The screen says so, because a list that looks like
    access control but is not would be a genuinely dangerous illusion.
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
    /*! smarton::models::AuthViewModel - for the email shape check, which lives
        there because it is the same rule the profile form uses. */
    required property var authViewModel

    /*! Add the member described by \c draft, then say what happened. */
    function addMember(): void {
        const id = root.viewModel.addMemberDetailed(draft.name, draft.email,
                                                    draft.phone,
                                                    draft.avatarUrl.toString(),
                                                    draft.password, draft.role);
        if (id.length === 0) {
            Notifications.error(qsTr("Could not add member"),
                                root.viewModel.lastMemberError);
            return;
        }

        Notifications.success(
            draft.password.length > 0
                ? qsTr("%1 can now sign in").arg(draft.name.trim())
                : qsTr("%1 added").arg(draft.name.trim()),
            draft.password.length > 0
                ? qsTr("Their sign-in name is %1.")
                    .arg(draft.email.trim().length > 0 ? draft.email.trim()
                                                       : draft.name.trim())
                : qsTr("No sign-in - a name on the household list."));
        draft.reset();
    }

    signal backRequested()

    StTopBar {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacing6
        anchors.bottomMargin: 0
        titleRowHeight: 92
        showBack: root.canGoBack
        eyebrow: root.viewModel.spaceName
        title: qsTr("Members")
        onBackRequested: root.backRequested()

        trailing: Component {
            StCountChip {
                ground: Theme.surfaceDeep     // the header band
                value: root.viewModel.memberCount
                noun: qsTr("Members")
                accent: Theme.warning
            }
        }
    }

    FileDialog {
        id: memberPicture

        title: qsTr("Choose a picture for this member")
        // Filtered by what the build can decode. The store re-checks by
        // CONTENT anyway - an extension filter is a convenience, never a
        // validation.
        nameFilters: [qsTr("Images (*.png *.jpg *.jpeg *.webp *.bmp)")]
        onAccepted: draft.avatarUrl = memberPicture.selectedFile
    }

    /*! The form's values, held outside the fields so Clear and the enabled
        state of Add can both reach them. */
    QtObject {
        id: draft

        property string name: ""
        property string email: ""
        property string phone: ""
        property string password: ""
        property string role: "viewer"
        property url    avatarUrl: ""

        function reset(): void {
            draft.name = "";
            draft.email = "";
            draft.phone = "";
            draft.password = "";
            draft.role = "viewer";
            draft.avatarUrl = "";
        }
    }

    /*! Name is the only requirement. Everything else is optional by design -
        a household member may have no email, no phone and no reason to sign
        in, and a form that demands all four is a form people abandon. */
    readonly property bool memberValid:
        draft.name.trim().length > 0
        && (draft.email.length === 0
            || root.authViewModel.isPlausibleEmail(draft.email))

    StCard {
        id: inviteCard

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.margins: Theme.spacing6
        height: inviteBody.implicitHeight + Theme.spacing6 * 2

        Column {
            id: inviteBody

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacing6
            spacing: Theme.spacing4

            Row {
                width: parent.width
                spacing: Theme.spacing5

                // ---- picture -------------------------------------------
                Column {
                    spacing: Theme.spacing2

                    StAvatar {
                        size: 84
                        source: draft.avatarUrl
                        name: draft.name
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StLinkButton {
                        text: draft.avatarUrl.toString().length > 0
                              ? qsTr("Change") : qsTr("Add photo")
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: memberPicture.open()
                    }
                }

                // ---- fields --------------------------------------------
                Grid {
                    id: fieldGrid

                    width: parent.width - 84 - parent.spacing
                    columns: 2
                    columnSpacing: Theme.spacing4
                    rowSpacing: Theme.spacing4

                    readonly property real cellWidth:
                        (fieldGrid.width - fieldGrid.columnSpacing) / 2

                    StFormField {
                        width: fieldGrid.cellWidth
                        label: qsTr("Name")
                        StTextField {
                            id: memberName
                            width: parent.width
                            text: draft.name
                            placeholderText: qsTr("Jack Sparrow")
                            onTextChanged: draft.name = memberName.text
                        }
                    }

                    StFormField {
                        width: fieldGrid.cellWidth
                        label: qsTr("Email (optional)")
                        StTextField {
                            id: memberEmail
                            width: parent.width
                            text: draft.email
                            placeholderText: qsTr("jack@example.com")
                            // Shape only. SmarTon has no mail transport, so a
                            // strict pattern would reject valid addresses and
                            // still accept ones that bounce.
                            errorText: memberEmail.text.length > 0
                                       && !root.authViewModel.isPlausibleEmail(memberEmail.text)
                                       ? qsTr("That does not look like an email address.")
                                       : ""
                            inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
                            onTextChanged: draft.email = memberEmail.text
                        }
                    }

                    StFormField {
                        width: fieldGrid.cellWidth
                        label: qsTr("Mobile (optional)")
                        StTextField {
                            id: memberPhone
                            width: parent.width
                            text: draft.phone
                            placeholderText: qsTr("+00 00 00 0000")
                            // No format enforcement. Number formats vary by
                            // country and rejecting a valid one is worse than
                            // storing it exactly as typed.
                            inputMethodHints: Qt.ImhDialableCharactersOnly
                            onTextChanged: draft.phone = memberPhone.text
                        }
                    }

                    StFormField {
                        width: fieldGrid.cellWidth
                        label: qsTr("Password (optional)")
                        StTextField {
                            id: memberPassword
                            width: parent.width
                            text: draft.password
                            password: true
                            placeholderText: qsTr("Leave empty for no sign-in")
                            onTextChanged: draft.password = memberPassword.text
                        }
                    }
                }
            }

            // Only once a password is being typed. Showing the rules and the
            // role picker unconditionally would imply every member needs an
            // account, which is the opposite of the intent.
            Column {
                width: parent.width
                spacing: Theme.spacing3
                visible: draft.password.length > 0

                StPasswordRules {
                    id: memberRules
                    width: parent.width
                    password: draft.password
                }

                Row {
                    spacing: Theme.spacing4

                    StLabel {
                        text: qsTr("Can do")
                        level: 1
                        tone: "secondary"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StSegmentedControl {
                        anchors.verticalCenter: parent.verticalCenter
                        model: [qsTr("View only"), qsTr("Guest control"),
                                qsTr("Control devices"), qsTr("Installer"),
                                qsTr("Administrator"), qsTr("Owner")]
                        currentIndex: draft.role === "owner"         ? 5
                                    : draft.role === "administrator" ? 4
                                    : draft.role === "installer"     ? 3
                                    : draft.role === "operator"      ? 2
                                    : draft.role === "guest"         ? 1 : 0
                        onSelected: index => draft.role = ["viewer", "guest", "operator",
                                                            "installer", "administrator", "owner"][index]
                    }
                }

                StLabel {
                    width: parent.width
                    text: qsTr("They will sign in with %1 and this password.")
                            .arg(draft.email.trim().length > 0 ? draft.email.trim()
                                                               : draft.name.trim())
                    level: 0
                    tone: "muted"
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }

            Row {
                anchors.right: parent.right
                spacing: Theme.spacing3

                StButton {
                    text: qsTr("Clear")
                    variant: "ghost"
                    width: 120
                    onClicked: draft.reset()
                }

                StButton {
                    iconName: "plus"
                    text: qsTr("Add member")
                    width: 200
                    // A password half-typed is not a password. Requiring the
                    // rules to pass BEFORE the button lights means the failure
                    // is visible where it happened rather than as a toast
                    // after a round trip.
                    enabled: root.memberValid
                             && (draft.password.length === 0 || memberRules.acceptable)
                    onClicked: root.addMember()
                }
            }
        }
    }

    StLabel {
        id: scopeNote

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: inviteCard.bottom
        anchors.margins: Theme.spacing6
        anchors.topMargin: Theme.spacing3
        text: qsTr("A member with a password can sign in on this panel. One without is a name and a face on the household list, and grants no access.")
        level: 0
        tone: "muted"
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    /*! Caption above a field. The design labels every input on this form. */
    component StFormField: Column {
        id: formField

        property string label: ""

        spacing: Theme.spacing2

        StLabel {
            text: formField.label
            level: 1
            tone: "secondary"
        }
    }

    GridView {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: scopeNote.bottom
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing6
        anchors.topMargin: Theme.spacing4
        clip: true
        cellWidth: width / 3
        // 112, not 100: the row now carries a name-plus-badge line above a
        // contact line, and at 100 the badge clipped against the card edge.
        cellHeight: 112
        model: root.viewModel.members

        delegate: Item {
            id: memberCell

            required property var model

            width: GridView.view.cellWidth
            height: GridView.view.cellHeight

            StCard {
                anchors.fill: parent
                anchors.rightMargin: Theme.spacing4
                anchors.bottomMargin: Theme.spacing4

                StAvatar {
                    id: avatar
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacing4
                    anchors.verticalCenter: parent.verticalCenter
                    size: 48
                    name: memberCell.model.name
                    source: memberCell.model.avatar
                    showPresence: true
                    online: memberCell.model.online
                }

                Column {
                    anchors.left: avatar.right
                    anchors.leftMargin: Theme.spacing4
                    anchors.right: removeButton.left
                    anchors.rightMargin: Theme.spacing2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Row {
                        width: parent.width
                        spacing: Theme.spacing2

                        StLabel {
                            text: memberCell.model.name
                            level: 2
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth,
                                            parent.width - (signInBadge.visible
                                                            ? signInBadge.width + parent.spacing
                                                            : 0))
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Says which KIND of member this is. Two things now
                        // live in this list - people who can sign in and
                        // people who are just on the household - and a list
                        // that does not distinguish them cannot be audited.
                        Rectangle {
                            id: signInBadge

                            visible: memberCell.model.canSignIn
                            width: badgeLabel.implicitWidth + Theme.spacing3
                            height: 20
                            radius: 10
                            color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.18)
                            border.width: Theme.borderWidth
                            border.color: Qt.rgba(Theme.info.r, Theme.info.g,
                                                  Theme.info.b, 0.5)
                            anchors.verticalCenter: parent.verticalCenter

                            StLabel {
                                id: badgeLabel
                                anchors.centerIn: parent
                                text: qsTr("Can sign in")
                                level: 0
                                color: Theme.infoSoft
                            }
                        }
                    }

                    StLabel {
                        width: parent.width
                        // Whichever contact detail exists, without an empty
                        // line when neither does.
                        text: memberCell.model.email.length > 0
                              ? memberCell.model.email
                              : memberCell.model.phone
                        level: 1
                        tone: "secondary"
                        visible: text.length > 0
                        elide: Text.ElideRight
                    }
                }

                StIconButton {
                    id: removeButton
                    glyph: "close"
                    size: 36
                    accessibleName: qsTr("Remove %1").arg(memberCell.model.name)
                    fill: "transparent"
                    stroke: Theme.danger
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacing3
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: root.viewModel.removeMember(memberCell.model.memberId)
                }
            }
        }
    }
}
