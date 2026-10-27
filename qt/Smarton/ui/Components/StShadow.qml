import QtQuick
import QtQuick.Effects
import SmarTon.Ui.Theme

/*!
    \qmltype StShadow
    \inqmlmodule SmarTon.Ui.Components
    \brief Soft drop shadow for a rounded tile.

    USAGE. Place it as the FIRST child of a card's root Item, filling it, with
    the same radius as the card:

    \qml
    Item {
        StShadow { anchors.fill: parent; radius: Theme.radiusLg }
        Rectangle { anchors.fill: parent; radius: Theme.radiusLg; color: ... }
    }
    \endqml

    HOW IT WORKS, AND WHY IT LOOKS LIKE A TRICK. MultiEffect has no
    shadow-only mode: it always draws its source as well as the shadow. So the
    source here is an opaque black rounded rectangle exactly the size of the
    card, and the card - which is opaque and sits on top - covers it
    completely. Only the blur spilling past the edges is ever visible.

    That means the card above MUST be opaque. On a translucent card the black
    source shows through and the tile goes muddy; use a border instead.

    \c autoPaddingEnabled lets the blur draw outside the item's bounds, which
    is what stops the shadow being clipped to the card's own rectangle.
*/
Item {
    id: root

    property real radius: Theme.radiusLg
    property color color: Theme.shadowColor
    property real blur: Theme.shadowBlur
    property int offsetY: Theme.shadowOffsetY

    // Nothing to lay out: this item only ever paints behind its sibling.
    visible: Theme.shadowsEnabled

    Rectangle {
        id: shape

        anchors.fill: parent
        radius: root.radius
        color: "black"
        // Never drawn directly - it exists to be the effect's source texture.
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: shape
        source: shape
        shadowEnabled: true
        shadowColor: root.color
        shadowBlur: root.blur
        shadowVerticalOffset: root.offsetY
        shadowHorizontalOffset: 0
        blurMax: Theme.shadowMaxBlur
        autoPaddingEnabled: true
    }
}
