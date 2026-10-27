import QtQuick
import QtQuick.Controls.Basic as QQC
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls
import SmarTon.Ui.Components

/*!
    \qmltype ScenariosScreen
    \inqmlmodule SmarTon.Ui.Screens
    \brief Scene list with a room filter. Figma frame 23.

    The room chips filter the SAME scene model rather than each holding a list,
    so a scene toggled here is already on when its room is opened.

    "Add new scene" is not wired: a scene needs a schedule editor and a device
    picker (frames 24-25), and a button that opens nothing is worse than one
    that says what it is waiting for.
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

    property int filterIndex: 0

    signal backRequested()
    signal addSceneRequested()
    signal editSceneRequested(string sceneId)

    /*! [{ id, name }, ...] from the view model - never role numbers. */
    property var filters: []

    function applyFilter(index: int): void {
        if (index < 0 || index >= root.filters.length)
            return;
        root.filterIndex = index;
        root.viewModel.setSceneFilter(root.filters[index].id);
    }

    Component.onCompleted: {
        root.filters = root.viewModel.roomFilters();
        root.applyFilter(0);
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacing6
        spacing: Theme.spacing5

        StTopBar {
            width: parent.width
            showBack: root.canGoBack
            eyebrow: qsTr("Devices")
            title: qsTr("All scenarios")
            onBackRequested: root.backRequested()

            trailing: Component {
                Row {
                    spacing: Theme.spacing3

                    Repeater {
                        model: root.filters

                        delegate: StChip {
                            required property int index
                            required property var modelData

                            text: modelData.name
                            selected: index === root.filterIndex
                            onClicked: root.applyFilter(index)
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 52

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StLabel { text: qsTr("Scenes"); level: 3 }
                StLabel {
                    text: qsTr("Organize your space by adding and customizing scenes")
                    level: 1
                    tone: "secondary"
                }
            }

            StButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 210
                variant: "secondary"
                iconName: "plus"
                text: qsTr("Add new scene")
                visible: root.viewModel.canAdminister
                onClicked: root.addSceneRequested()
            }
        }

        Grid {
            id: sceneGrid

            width: parent.width
            columns: 2
            columnSpacing: Theme.cardGap
            rowSpacing: Theme.cardGapV

            readonly property real cellWidth:
                (sceneGrid.width - sceneGrid.columnSpacing) / sceneGrid.columns

            Repeater {
                model: root.viewModel.scenes

                delegate: StSceneCard {
                    required property var model
                    required property int index

                    width: sceneGrid.cellWidth
                    name: model.name
                    days: model.days
                    timeRange: model.timeRange
                    deviceCount: model.deviceCount
                    enabled: model.isEnabled

                    onToggled: requested =>
                        root.viewModel.scenes.setEnabled(index, requested)
                    onRenamed: newName =>
                        root.viewModel.scenes.rename(index, newName)
                    onActivated: root.editSceneRequested(model.sceneId)
                }
            }
        }

        StEmptyState {
            width: parent.width
            height: 220
            visible: root.viewModel.scenes.count === 0
            title: qsTr("No scenes in this room yet.")
            detail: qsTr("Scenes run your devices on a schedule. The editor is designed (frames 24-25) and is not built yet.")
        }
    }
}
