import QtQuick
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StTopBar
    \inqmlmodule SmarTon.Ui.Components
    \brief The header band every content frame opens with.

    Figma frames 07 and 10-27 all share it: a rounded dark band carrying the
    decorative line artwork, an optional back button, an eyebrow over a title,
    and a trailing slot for whatever that screen puts on the right.

    Three title arrangements appear in the design and all three are this
    component: title only, left-aligned (07, 18); eyebrow over title with a
    back button (19, 21, 26); centred title over subtitle (10-17, via
    \l centred).

    The band can be TALLER than its title row - frame 07 hangs the conditions
    strip below the word "Spaces" inside the same band. So the title row is a
    fixed \l titleRowHeight pinned to the top, and any extra height belongs to
    whatever the caller anchors underneath. Centring the title in the whole
    band instead would drop it on top of that content, which is exactly what
    the first version of this file did.
*/
Item {
    id: root

    property string eyebrow: ""
    property string title: ""
    property string subtitle: ""
    property bool   showBack: false
    property bool   centred: false
    /*! Height of the title row. Measured: the picker centres at y=57 on frame
        07, so the row is 0..114. */
    property int    titleRowHeight: 116

    /*!
        Content hung BELOW the title row, inside the same band - the
        conditions strip on frames 07 and 18.

        A Component in a Loader, and the band sizes itself around it. The
        previous arrangement had callers set an absolute `height: 200` and
        anchor the strip to the band's BOTTOM, which is how the space picker
        ended up overlapping it: the picker centres in the title row at y=30..85
        and a bottom-anchored 100 px strip lands at y=80..180. Five pixels of
        overlap, from two independent guesses about the same band.
    */
    property Component bottomContent: null
    /*! Gap under the bottom content, measured 25 on frame 07. */
    property int    bottomPadding: Theme.spacing6

    /*!
        Trailing content, right-aligned in the title row.

        A Component in a Loader, not an Item slot: a slot sized by childrenRect
        loops the moment someone anchors a child to it, and "someone" is every
        future screen. A Loader takes its size from the item's implicit size,
        which cannot loop.
    */
    property Component trailing: null

    signal backRequested()

    // The band measures itself. Nothing outside it has to know the sum.
    implicitHeight: root.titleRowHeight
                    + (bottomSlot.active
                       ? bottomSlot.implicitHeight + root.bottomPadding : 0)
    // A transparent bar has no band to size, so it must not claim the width -
    // it floats over content that is already filling the space.
    height: root.transparent ? root.titleRowHeight : implicitHeight

    /*! What the glass header blurs. See StGlass. */
    property Item backdrop: null

    /*!
        Draw no band at all - just the title row over whatever is behind.

        For frame 20, where the room PHOTOGRAPH is the header's background and
        a band drawn over it would cut the room in half. A property rather
        than a second component, because everything else about the bar - the
        back button, the eyebrow, the trailing slot, the measuring - is
        identical, and a copy would drift.
    */
    property bool transparent: false

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceDeep
        visible: !Theme.glass && !root.transparent
    }

    StGlass {
        anchors.fill: parent
        visible: Theme.glass && !root.transparent
        radius: Theme.radiusLg
        backdrop: root.backdrop !== null ? root.backdrop : Backdrop.source
        // One of the few surfaces that earns a real blur: it is large, it
        // spans the aurora, and there is exactly one of it per screen. See
        // StGlass.frosted for why cards do not get this.
        frosted: true
    }

    // Decoration: anchored right and cropped, as the frames show it. It never
    // influences the band's size.
    //
    // Masked rather than clipped inside the band. `clip: true` clips to the
    // BOUNDING BOX, so the artwork ran square past the band's rounded corners
    // and put a hard right angle over the top-right radius - subtle at 55%
    // opacity on a dark ground, and the reason that corner never looked as
    // round as the others.
    StRoundedImage {
        anchors.fill: parent
        radius: Theme.radiusLg
        source: "qrc:/qt/qml/SmarTon/Resources/images/brand/deco-lines.png"
        fillMode: Image.PreserveAspectCrop
        horizontalAlignment: Image.AlignRight
        visible: !root.transparent
        // Dimmed rather than hidden under glass. At full strength the line
        // artwork competes with the aurora showing through the panel and the
        // header turns into noise; removed entirely, the band loses the one
        // piece of brand texture it carries.
        opacity: Theme.glass ? 0.18 : 0.55
    }

    Item {
        id: titleRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.titleRowHeight

        StIconButton {
            id: backButton
            glyph: "back"
            accessibleName: qsTr("Back")
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showBack
            onClicked: root.backRequested()
        }

        Column {
            anchors.left: root.showBack ? backButton.right : parent.left
            anchors.leftMargin: Theme.spacing5
            anchors.right: trailingSlot.left
            anchors.rightMargin: Theme.spacing5
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: !root.centred

            StLabel {
                width: parent.width
                text: root.eyebrow
                level: 1
                tone: "secondary"
                visible: root.eyebrow.length > 0
            }

            StLabel {
                width: parent.width
                text: root.title
                level: 3
            }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width * 0.5
            spacing: 2
            visible: root.centred

            StLabel {
                width: parent.width
                text: root.title
                level: 3
                horizontalAlignment: Text.AlignHCenter
            }

            StLabel {
                width: parent.width
                text: root.subtitle
                level: 1
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
                visible: root.subtitle.length > 0
            }
        }

        Loader {
            id: trailingSlot

            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing5
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: root.trailing
        }
    }

    Loader {
        id: bottomSlot

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleRow.bottom
        anchors.leftMargin: Theme.spacing5
        anchors.rightMargin: Theme.spacing5
        active: root.bottomContent !== null
        sourceComponent: root.bottomContent
    }
}
