pragma Singleton
import QtQml

/*!
    \qmltype FocusHelper
    \inqmlmodule SmarTon.Ui.Helpers
    \brief Finding the field a screen should open on.

    Every screen used to answer this for itself, which in practice meant only
    the login screen did: a wizard step with one text field opened with focus
    nowhere, so the first keystroke went to the StackView and vanished. On a
    panel with a keyboard attached that is the difference between typing a
    house name and wondering why the app is ignoring you.

    A MARKER PROPERTY, NOT DUCK TYPING. The walk looks for \c stTextInput,
    declared by the input controls themselves, rather than sniffing for a
    \c placeholderText property. Duck typing finds whatever happens to look
    like a text field today - including controls that merely expose a similar
    property - and changes behaviour silently when an unrelated control gains
    one. A marker is a control saying "I am a place to type", which is the
    actual question being asked.

    A SINGLETON RATHER THAN A .js FILE, because a QML singleton is resolved
    through the module URI like every other type here, while a JS import is
    resolved by relative path into the resource tree - which works until a
    module's output directory moves.
*/
QtObject {
    id: root

    /*! Depth-first in declaration order. Skips anything hidden or disabled. */
    function findFirstField(item: var): var {
        if (!item || item.visible === false || item.enabled === false)
            return null;

        if (item.stTextInput === true && item.readOnly !== true)
            return item;

        // `children` is the VISUAL child list, so a Loader's loaded item is
        // included once it exists - which is what makes this work for the
        // wizard steps, where the field lives in a Component swapped per step.
        const kids = item.children;
        if (kids === undefined)
            return null;

        for (let i = 0; i < kids.length; ++i) {
            const found = root.findFirstField(kids[i]);
            if (found !== null)
                return found;
        }
        return null;
    }

    /*!
        Focus the first typeable field under \a item.

        Returns true when something was focused, so a caller can tell "no field
        on this screen" from "done" rather than guessing.
    */
    function focusFirstField(item: var): bool {
        const field = root.findFirstField(item);
        if (field === null)
            return false;

        // No reason argument, which means Qt.OtherFocusReason - and that is
        // the one wanted: the controls draw their focus RING only for keyboard
        // navigation, and arriving on a screen is not that. The caret appears,
        // the ring does not, which is what a person expects when a form opens
        // ready to type.
        //
        // Passing the enum explicitly would be clearer and does not work here:
        // the focus-reason values live on QtQuick's Qt object, and this
        // singleton imports QtQml only so that a pure logic helper does not
        // drag the scene graph in.
        field.forceActiveFocus();
        return true;
    }
}
