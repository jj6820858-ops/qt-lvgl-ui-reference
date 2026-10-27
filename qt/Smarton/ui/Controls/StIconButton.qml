import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StIconButton
    \inqmlmodule SmarTon.Ui.Controls
    \brief Square icon-only button. Figma: the back arrow, the edit pencil,
           the dialog close, the room card overflow.

    The glyph comes from the shared SVG set via StIcon. It used to be a Canvas
    with a switch over seven hand-drawn paths - which meant this file owned an
    icon library, drifted from every other one, and repainted on every colour
    change.
*/
T.Button {
    id: root

    /*! Any name from resources/icons/ui - see StIcon. */
    property string glyph: "back"
    property color  stroke: Theme.textPrimary
    property color  fill: Theme.surface
    property int    size: 44
    property int    radius: Theme.radiusSm
    property color  borderColor: "transparent"
    property int    borderWidth: 0

    /*!
        THE DRAWN SIZE, not the target.

        \l size is what the design draws; the item is that or the touch
        minimum, whichever is larger, and the disc is centred in it. Half the
        icon buttons in this app are 36 or 40 px because that is what the
        frames show, and 36 px is a target people miss on a panel screwed to a
        wall. Growing the drawing to fix that would have been a redesign;
        growing the target is invisible and correct.
    */
    implicitWidth: Math.max(root.size, Theme.touchTarget)
    implicitHeight: Math.max(root.size, Theme.touchTarget)
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    activeFocusOnTab: true

    /*! Spoken label. Required: an icon-only button has no text to fall back
        on, so without this a screen reader announces "button" and nothing
        else. Defaulted from the glyph so it is never silent, but every call
        site that means something more specific should say so. */
    property string accessibleName: root.glyph

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.onPressAction: root.clicked()

    // A transparent Item holding a centred disc, not a Rectangle filling the
    // control: T.Button stretches its background over the whole item, and the
    // whole item is now the touch target rather than the drawing.
    background: Item {
        Rectangle {
            anchors.centerIn: parent
            width: root.size
            height: root.size
            radius: root.radius
            color: !root.enabled ? root.fill
                 : root.down      ? Theme.pressedFill(Theme.surfaceRaised)
                 : root.hovered   ? (root.fill === "transparent"
                                     ? Qt.rgba(1, 1, 1, Theme.hoverOverlay)
                                     : Theme.hoveredFill(root.fill, true))
                                  : root.fill
            opacity: root.enabled ? 1 : Theme.disabledOpacity
            border.width: root.visualFocus ? Theme.borderWidthFocus : root.borderWidth
            border.color: root.visualFocus ? Theme.focus : root.borderColor

            Behavior on color {
                ColorAnimation { duration: Theme.durationFast }
            }
        }
    }

    contentItem: Item {
        StIcon {
            anchors.centerIn: parent
            name: root.glyph
            size: root.size >= 44 ? 20 : 16
            color: root.enabled ? root.stroke : Theme.textDisabled
        }
    }
}
