import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StCard
    \inqmlmodule SmarTon.Ui.Components
    \brief The elevated surface every panel in the app sits on.

    One component so card colour, radius, border and elevation are defined
    once. The Figma uses exactly two treatments - plain and selected - and
    \l selected is the second, used by the scene rows on frame 23.

    NO DEFAULT-PROPERTY ALIAS, DELIBERATELY. Routing children into the surface
    with \c {default property alias content: surface.data} would also capture
    the StShadow declared in this file, putting the shadow INSIDE the surface
    that is supposed to cast it - where it is painted over and clipped away.
    So children stay plain siblings: they are declared after the surface, so
    they paint on top of it, and the surface fills the root, so anchoring to
    \c parent gives the same geometry either way.
*/
Item {
    id: root

    property bool selected: false
    property bool interactive: false
    /*! Outlined: a 1 px border over the page ground, no fill and no shadow.
        Measured on the Members and space-map cards of frame 07, which were
        drawn as solid `surface` - far too heavy against the device grid
        above them. */
    property bool outlined: false
    property color color: Theme.surface
    property real radius: Theme.radiusLg

    signal clicked()

    /*!
        What the glass surface blurs.

        Nominated by the caller because Qt has no backdrop filter - see
        StGlass. A card with no backdrop set still gets the film and the rim,
        which is most of the effect; it just has nothing to frost.
    */
    property Item backdrop: null

    StShadow {
        anchors.fill: parent
        radius: root.radius
        // An outlined card casts nothing: it is a boundary, not a surface.
        visible: Theme.shadowsEnabled && !root.outlined
    }

    // ---- the two treatments -------------------------------------------------
    // Both live here rather than the screens choosing, so a screen written for
    // one theme is automatically correct in the other. That is the whole
    // argument for having a token layer, and the only way to test it is to
    // have a second theme actually use it.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: !Theme.glass
        color: root.outlined ? "transparent" : root.color
        border.width: root.selected ? Theme.borderWidthFocus : Theme.borderWidth
        border.color: root.selected  ? Theme.primary
                    : root.outlined  ? Theme.surfaceRaised   // measured #40464D
                                     : Theme.outlineSubtle

        Behavior on border.width {
            NumberAnimation { duration: Theme.durationFast }
        }
    }

    StGlass {
        anchors.fill: parent
        visible: Theme.glass
        radius: root.radius
        backdrop: root.backdrop
        // An outlined card is a boundary, so it stays the thinner film even in
        // the glass theme - the hierarchy the Figma treatment encodes with
        // fill weight has to survive the reskin.
        raised: !root.outlined
        highlighted: root.selected
    }

    TapHandler {
        enabled: root.interactive
        onTapped: root.clicked()
    }
}
