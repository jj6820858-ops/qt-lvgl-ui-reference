import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StLabel
    \inqmlmodule SmarTon.Ui.Controls
    \brief Text with the SmarTon type scale and colour roles applied.

    Exists so no other component sets a raw font size or colour.
*/
Text {
    id: root

    /*! 0 caption, 1 body, 2 subtitle, 3 title, 4 display. */
    property int level: 1
    /*! primary | secondary | muted | disabled | brand | active */
    property string tone: "primary"

    color: {
        switch (root.tone) {
        case "secondary": return Theme.textSecondary;
        case "muted":     return Theme.textMuted;
        case "disabled":  return Theme.textDisabled;
        case "brand":     return Theme.primary;
        case "active":    return Theme.textOnActive;
        default:          return Theme.textPrimary;
        }
    }
    font.family: Theme.fontFamily
    font.pixelSize: {
        switch (root.level) {
        case 0:  return Theme.fontSizeCaption;
        case 2:  return Theme.fontSizeSubtitle;
        case 3:  return Theme.fontSizeTitle;
        case 4:  return Theme.fontSizeDisplay;
        default: return Theme.fontSizeBody;
        }
    }
    font.weight: root.level >= 3 ? Theme.fontWeightBold : Theme.fontWeightRegular
    // QtRendering, not NativeRendering. Native is sharper only at integer
    // device positions; every label here sits inside a Flickable, a Column
    // that animates, or a card that fades, all of which put text on
    // fractional offsets where Native visibly shimmers frame to frame.
    renderType: Text.QtRendering
    elide: Text.ElideRight

    // Headings announce as headings so a screen reader can jump between them.
    Accessible.role: root.level >= 3 ? Accessible.Heading : Accessible.StaticText
    Accessible.name: root.text
}
