pragma Singleton
import QtQml

/*!
    \qmltype Notifications
    \inqmlmodule SmarTon.Ui.Helpers
    \brief The one place anything in the app says "that worked" or "that did not".

    THE PROBLEM IT SOLVES. Feedback was ad hoc: a status string on the auth
    view model that one screen bound to, an error line on the login form, and
    on most actions nothing at all - editing a profile field and pressing Save
    produced no visible response whatsoever, so the only way to find out
    whether it worked was to leave and come back. A person cannot tell "saved"
    from "silently failed", and will assume the worse one.

    A SINGLETON QUEUE, NOT A COMPONENT PER SCREEN. Toasts have to outlive the
    screen that raised them - "Saved" belongs on screen while the user is
    already navigating away - and two screens must never stack two overlays.
    So this holds the state and one StToastHost in Main.qml draws it.

    NO C++ INVOLVED. A toast is a statement about what just happened in the
    UI, and routing it through a view model would put presentation timing into
    the layer that is meant not to have any. View models report FACTS - an
    error string, a busy flag - and the screen decides whether that deserves a
    toast.
*/
QtObject {
    id: root

    /*! info | success | warning | error */
    readonly property string kindInfo:    "info"
    readonly property string kindSuccess: "success"
    readonly property string kindWarning: "warning"
    readonly property string kindError:   "error"

    /*! The queue. StToastHost renders element 0 and calls dismiss(). */
    property var queue: []
    readonly property bool active: root.queue.length > 0
    readonly property var current: root.active ? root.queue[0] : null

    /*!
        How long each kind stays up.

        Not one duration for all four. An error is the one a person most needs
        time to read and most likely arrived while they were looking elsewhere,
        and a success is the one they already expected - so they earn different
        amounts of attention. Errors also stay until dismissed if they carry an
        action, because a toast that vanishes mid-decision is worse than none.
    */
    function durationFor(kind: string): int {
        switch (kind) {
        case root.kindError:   return 7000;
        case root.kindWarning: return 5500;
        default:               return 3500;
        }
    }

    function show(kind: string, message: string, detail: string): void {
        if (message.length === 0)
            return;

        const entry = {
            kind: kind,
            message: message,
            detail: detail === undefined ? "" : detail,
            // Sequence, not a timestamp: two toasts raised in the same
            // millisecond would otherwise be indistinguishable to the host's
            // change detection and the second would not animate in.
            id: ++root._sequence
        };

        // Collapse an identical repeat rather than queueing it. Pressing Save
        // twice should not mean reading "Saved" twice.
        const q = root.queue.slice();
        if (q.length > 0 && q[q.length - 1].message === entry.message
            && q[q.length - 1].kind === entry.kind)
            return;

        q.push(entry);
        root.queue = q;
    }

    function info(message: string, detail: string): void {
        root.show(root.kindInfo, message, detail);
    }
    function success(message: string, detail: string): void {
        root.show(root.kindSuccess, message, detail);
    }
    function warning(message: string, detail: string): void {
        root.show(root.kindWarning, message, detail);
    }
    function error(message: string, detail: string): void {
        root.show(root.kindError, message, detail);
    }

    /*! Drop the front of the queue. Called by the host when it times out or
        the user dismisses it. */
    function dismiss(): void {
        if (root.queue.length === 0)
            return;
        root.queue = root.queue.slice(1);
    }

    function clear(): void {
        root.queue = [];
    }

    property int _sequence: 0
}
