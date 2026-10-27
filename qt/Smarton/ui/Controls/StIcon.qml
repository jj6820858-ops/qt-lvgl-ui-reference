import QtQuick
import QtQuick.Effects
import SmarTon.Ui.Theme

/*!
    \qmltype StIcon
    \inqmlmodule SmarTon.Ui.Controls
    \brief The one way an icon is drawn in SmarTon.

    Every glyph used to be a Canvas painted by hand, per control. That gave
    three problems that only show up once there are thirty of them: stroke
    weights drifted (1.6 here, 1.7 there, 1.8 in the calendar), optical sizes
    were inconsistent because each was drawn to fill its own box, and every
    icon cost a repaint whenever its colour changed.

    They are now a real set: 31 SVGs on one 24x24 grid, 1.5 stroke, round caps
    and joins, in `resources/icons/ui/`. One spec, one place.

    COLOURING. The SVGs are authored white and tinted at runtime with
    MultiEffect colorization, so one file serves every state - muted in a rail,
    white when active, orange on a link, `danger` on a delete. Authoring a
    coloured copy per state is how an icon set ends up with four almost-identical
    trash cans that fall out of sync.

    SIZES are a small fixed scale, because an icon set with arbitrary sizes
    stops looking like a set. 16 for inline, 20 for controls, 24 default, 32
    for empty states.
*/
Item {
    id: root

    /*! File stem under resources/icons/ui, e.g. "settings". */
    property string name: ""
    property color color: Theme.textPrimary
    /*! 16 | 20 | 24 | 32. Anything else is a bug in the caller. */
    property int size: 24
    // Qt Quick Effects requires a GPU-backed scene graph. The RK3328 EGLFS
    // deployment deliberately uses the software renderer, so show the
    // white SVG directly there rather than hiding it behind MultiEffect.
    readonly property bool softwareRenderer: GraphicsInfo.api === GraphicsInfo.Software

    implicitWidth: root.size
    implicitHeight: root.size

    Image {
        id: source

        anchors.fill: parent
        source: root.name.length > 0
                ? "qrc:/qt/qml/SmarTon/Resources/icons/ui/" + root.name + ".svg"
                : ""
        // Rasterised at the DEVICE size, not the layout size: an SVG decoded
        // at 24 and drawn at 24 on a 2x panel is visibly soft.
        sourceSize.width: root.size * Screen.devicePixelRatio
        sourceSize.height: root.size * Screen.devicePixelRatio
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        visible: root.softwareRenderer
    }

    MultiEffect {
        anchors.fill: source
        source: source
        colorization: 1.0
        colorizationColor: root.color
        // Blending the tint over an antialiased white stroke keeps the edge
        // rather than hard-keying it, which is what makes a 16 px icon legible.
        brightness: 0.0
        visible: !root.softwareRenderer
    }
}
