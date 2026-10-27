import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StSummaryHeader
    \inqmlmodule SmarTon.Ui.Components
    \brief The pale summary card. Figma frames 12-17, 24-25.

    THE ONE LIGHT SURFACE IN THE APP, and deliberately so: it is the only
    element that says "this is the thing you are editing" across eight wizard
    steps, and inverting it is what makes it read as a fixed reference while
    the content below it changes. Its text therefore uses \c surfaceDeep, not
    the theme's text roles, which are all tuned for dark backgrounds.
*/
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property url    thumbnailSource: ""
    property bool   editable: true
    /*! [{ value, noun, accent }, ...] - the pills on the right. */
    property var counts: []

    signal renamed(string name)

    implicitHeight: 124

    StShadow { anchors.fill: parent; radius: Theme.radiusXl }

    Rectangle {
        anchors.fill: parent
        // Measured 18 - the largest corner in the design, and deliberately so.
        radius: Theme.radiusXl
        color: Theme.textSecondary

        StRoundedImage {
            id: thumb
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacing3
            width: 132
            radius: Theme.radiusSm
            source: root.thumbnailSource
        }

        Column {
            anchors.left: thumb.right
            anchors.leftMargin: Theme.spacing5
            anchors.right: pills.left
            anchors.rightMargin: Theme.spacing5
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StEditableLabel {
                text: root.title
                level: 3
                editable: root.editable
                onCommitted: name => root.renamed(name)
            }

            StLabel {
                text: root.subtitle
                level: 1
                color: Theme.surfaceAlt
                visible: root.subtitle.length > 0
            }
        }

        Row {
            id: pills
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing5
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing3

            Repeater {
                model: root.counts

                delegate: StCountChip {
                    id: countChip

                    required property var modelData

                    // The card is #D9DFE6. Stated rather than assumed, so the
                    // chip measures its text against the ground it is actually
                    // on instead of against the default.
                    ground: Theme.textSecondary
                    value: countChip.modelData.value
                    noun: countChip.modelData.noun
                    accent: countChip.modelData.accent === undefined
                            ? Theme.success : countChip.modelData.accent
                }
            }
        }
    }
}
