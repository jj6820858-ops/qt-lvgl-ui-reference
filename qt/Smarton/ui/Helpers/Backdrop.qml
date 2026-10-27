pragma Singleton
// QtQuick, not just QtQml: `source` is typed Item, which is a QtQuick type.
// Declared with only QtQml imported, the property type does not resolve, the
// singleton fails to load, and because ONE broken type invalidates a whole QML
// module, everything importing SmarTon.Ui.Helpers fails with it - which is why
// this surfaced as "StShadow unavailable" rather than as anything about a
// backdrop.
import QtQml
import QtQuick

/*!
    \qmltype Backdrop
    \inqmlmodule SmarTon.Ui.Helpers
    \brief Where the page's backdrop is, so glass surfaces can find it.

    Qt has no backdrop filter. An item cannot blur what is painted under it,
    because by the time it draws, what is under it is already in the
    framebuffer and unreadable. The only way to frost something is to blur a
    live COPY of a nominated source item - which means every glass surface
    needs a reference to that source.

    Threading that reference down through twenty screens, most of which live
    inside Loaders and Components, would be a property on every one of them
    that exists for no reason those screens care about - and the twenty-first
    screen would forget. There is exactly ONE backdrop per window, so a
    singleton is the honest shape: it is a fact about the window, not a
    parameter of a card.

    Set by StAurora, read by StGlass. Nothing else should write it.
*/
QtObject {
    id: root

    /*! The page backdrop, or null before one exists. Glass surfaces must cope
        with null - during startup, in the gallery, and in unit tests there is
        no backdrop at all, and a card that cannot render without one would
        take those cases down. */
    property Item source: null
}
