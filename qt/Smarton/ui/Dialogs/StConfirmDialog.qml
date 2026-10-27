import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StConfirmDialog
    \inqmlmodule SmarTon.Ui.Dialogs
    \brief Two-choice confirmation built on the Qt Quick Templates dialog.

    Derives from T.Dialog so modality, focus trapping, Esc handling and the
    overlay come from Qt rather than being reimplemented — the parts of a
    dialog that are easy to get subtly wrong.
*/
T.Dialog {
    id: root

    /*! \qmlproperty string StConfirmDialog::message  Body text. */
    property string message: ""

    /*! \qmlproperty string StConfirmDialog::acceptText  Confirm button label. */
    property string acceptText: qsTr("Confirm")

    /*! \qmlproperty string StConfirmDialog::rejectText  Cancel button label. */
    property string rejectText: qsTr("Cancel")

    /*! \qmlproperty bool StConfirmDialog::destructive  Tint the confirm action. */
    property bool destructive: false

    /*!
        Artwork above the title - the device the question is about.

        Frame 08 puts the lamp's photograph in the dialog, and it is doing
        real work rather than decorating: "Manage your lights / Turn off" is
        ambiguous about WHICH lights until you see one. A picture answers that
        faster than any wording of the sentence would.
    */
    property url artworkSource: ""
    property int artworkHeight: 150

    modal: true
    anchors.centerIn: T.Overlay.overlay
    padding: Theme.spacing6
    implicitWidth: Math.max(implicitContentWidth + leftPadding + rightPadding, 320)
    implicitHeight: implicitContentHeight + topPadding + bottomPadding + implicitHeaderHeight + implicitFooterHeight

    background: Rectangle {
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline
    }

    header: Column {
        spacing: 0

        // Centred, and with the soft disc behind it that every product shot
        // in this design sits on - without the disc a cut-out photograph
        // floats on the surface instead of sitting on it.
        Item {
            width: parent.width
            height: artwork.source.toString().length > 0
                    ? root.artworkHeight + Theme.spacing6 : 0
            visible: height > 0

            Rectangle {
                anchors.centerIn: artwork
                width: root.artworkHeight * 0.92
                height: width
                radius: width / 2
                color: Theme.textPrimary
                opacity: 0.05
            }

            Image {
                id: artwork

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacing6
                height: root.artworkHeight
                source: root.artworkSource
                fillMode: Image.PreserveAspectFit
                sourceSize.height: 300
                smooth: true
                asynchronous: true
            }
        }

        Item {
            width: parent.width
            implicitHeight: root.title.length > 0
                            ? titleLabel.implicitHeight + Theme.spacing6 : 0

            StLabel {
                id: titleLabel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.spacing6
                anchors.rightMargin: Theme.spacing6
                anchors.topMargin: Theme.spacing6
                text: root.title
                level: 3
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: root.title.length > 0
            }
        }
    }

    contentItem: StLabel {
        text: root.message
        level: 1
        tone: "secondary"
        // Centred under a centred title and a centred image. Left-aligned it
        // hangs off the composition, which is what frame 08 does not do.
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    footer: Row {
        spacing: Theme.spacing3
        padding: Theme.spacing6
        layoutDirection: Qt.RightToLeft

        StButton {
            text: root.acceptText
            variant: root.destructive ? "danger" : "primary"
            onClicked: root.accept()
        }

        StButton {
            text: root.rejectText
            variant: "secondary"
            onClicked: root.reject()
        }
    }

    T.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.55)
    }
}
