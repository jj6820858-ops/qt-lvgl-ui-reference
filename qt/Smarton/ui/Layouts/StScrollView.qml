import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StScrollView
    \inqmlmodule SmarTon.Ui.Layouts
    \brief A Flickable with a scrollbar and physics tuned for a touch panel.

    Every scrolling screen used a bare Flickable, which gives no indication
    that there is anything below the fold. On a 600 px panel showing content
    drawn for 1024 that is most screens, and people simply do not know to
    scroll.

    Drop-in: it IS a Flickable, so callers keep setting \c contentHeight
    exactly as before. Deliberately NOT a wrapper with a default-property
    alias - that would route this file's own scrollbar into the content
    holder along with the caller's children, and the bar would scroll away
    with them.

    \list
    \li The bar fades in while scrolling and dims after, so it indicates
        without permanently eating width from a narrow layout.
    \li \c StopAtBounds: bouncing past the end is a phone idiom that reads as
        a glitch on an appliance panel.
    \li \c pixelAligned, so text does not sit on half-pixels mid-flick.
    \endlist
*/
Flickable {
    id: root

    clip: true
    contentWidth: width
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 2500        // a finger, not a mouse wheel
    maximumFlickVelocity: 2800
    pixelAligned: true

    Rectangle {
        id: bar

        readonly property bool needed: root.contentHeight > root.height + 1
        readonly property real track: Math.max(1, root.contentHeight - root.height)

        // Positioned in CONTENT coordinates, so the viewport offset has to be
        // added back for it to stay put on screen while everything else moves.
        x: root.contentWidth - width - 2
        y: bar.needed
           ? root.contentY
             + (root.contentY / bar.track) * (root.height - bar.height)
           : 0
        width: Theme.scrollBarWidth
        height: bar.needed
                ? Math.max(32, (root.height / root.contentHeight) * root.height)
                : 0
        radius: width / 2
        color: Theme.outlineSubtle
        visible: bar.needed
        opacity: root.moving || root.dragging ? 0.85 : 0.22

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationNormal }
        }
    }
}
