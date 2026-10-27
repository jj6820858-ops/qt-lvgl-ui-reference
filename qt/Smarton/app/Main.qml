import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as QQC
import SmarTon.Ui.Components
import SmarTon.Ui.Theme
import SmarTon.Ui.Screens

/*!
    Application window and the OUTER navigation stack.

    Two stacks, two jobs. This one moves between the pre-login flow and the
    signed-in shell; the shell owns its own stack for its five destinations and
    their drill-downs (see ShellScreen). Signing in \c replaces rather than
    pushes, so there is no back path from inside the app to a login form still
    holding a password, and logging out replaces in the other direction so the
    shell and its view state are destroyed rather than left resident.

    Window size is the Waveshare 7" panel: 1024x600. It is resizable on the
    desktop for development, with a floor at the design size so a screen is
    never being judged at a size the design was never drawn for.
*/
Window {
    id: root

    /*! Injected from C++ via QQmlApplicationEngine::setInitialProperties(). */
    required property var authViewModel
    required property var homeViewModel
    /*! smarton::models::ActivityListModel - what happened in the house. */
    required property var activityModel
    /*! Restored from QSettings by the composition root, already clamped to the
        bounds below - the settings file is editable by hand, so a stored 0x0
        must never reach a window. */
    required property int startupWidth
    required property int startupHeight
    /*! Restored rail width, or 0 for the design default. */
    required property int startupSidebarWidth

    /*!
        The rail's live width, for main.cpp to store on the way out.

        Surfaced on the WINDOW rather than saved from inside the shell,
        because the shell is destroyed and recreated on every sign-out and a
        component that writes settings from its destructor writes them at the
        least predictable moment. The composition root already reads the window
        size off this object at aboutToQuit; this rides along.
    */
    property int sidebarWidth: root.startupSidebarWidth

    width: root.startupWidth
    height: root.startupHeight

    // Bounded both ways, on purpose.
    //
    // The floor is the design size: below 1024x600 the layouts are being
    // judged at a size nothing was drawn for, and the three-column grids
    // start clipping rather than reflowing.
    //
    // The ceiling exists because this is a PANEL application. Stretched to a
    // 4K desktop, a layout composed for 1024 does not become a better layout,
    // it becomes a sparse one with 300 px cards adrift in whitespace - and
    // then a screenshot of it misrepresents how the product actually looks.
    // On the panel itself the window manager runs it fullscreen at exactly
    // the minimum, so neither bound is ever reached in production.
    minimumWidth: Theme.windowMinWidth
    minimumHeight: Theme.windowMinHeight
    maximumWidth: Theme.windowMaxWidth
    maximumHeight: Theme.windowMaxHeight
    visibility: Window.FullScreen
    visible: true
    color: Theme.background
    title: qsTr("SmarTon")

    // Global activity detection for the idle lock.
    //
    // Handlers on the Window rather than on each screen: a lock that only
    // notices activity on screens someone remembered to instrument is a lock
    // that fires while the user is mid-task. HoverHandler and TapHandler here
    // see every pointer event before it reaches anything, and Keys sees every
    // key because the StackView below has focus.
    //
    // All three only report - none of them accept - so nothing downstream
    // changes behaviour because of this block.
    HoverHandler {
        onPointChanged: root.authViewModel.noteActivity()
    }

    TapHandler {
        acceptedButtons: Qt.AllButtons
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onGrabChanged: root.authViewModel.noteActivity()
    }

    Connections {
        target: root.authViewModel
        function onAuthenticated() {
            flow.replace(null, shellPage);
        }
        // One signal for "the session ended", whether the user pressed Log out
        // or the panel timed out. Two paths into the same place would be two
        // chances for one of them to leave the shell resident.
        function onSessionEnded() {
            if (flow.currentItem !== null && flow.depth > 0)
                flow.replace(null, loginPage);
        }
    }

    QQC.StackView {
        id: flow

        anchors.fill: parent
        Keys.onPressed: function (event) {
            root.authViewModel.noteActivity();
            event.accepted = false;
        }
        // A remembered panel starts signed in. main.cpp attempts the resume
        // BEFORE the engine loads, so by the time this is evaluated the answer
        // already exists - and the authenticated() signal it emitted arrived
        // before this Connections block existed, which is why the state is
        // read here rather than waited for.
        initialItem: root.authViewModel.signedIn ? shellPage : splashPage
        focus: true

        // Transitions off. A cross-fade between two full screens on the panel
        // costs a composited layer per side for the length of the animation,
        // and on the RK3328 that is visible as a hitch on exactly the action
        // that should feel instant. Assigned null rather than deleted so the
        // decision is visible and reversible in one place.
        pushEnter: null
        pushExit: null
        popEnter: null
        popExit: null
        replaceEnter: null
        replaceExit: null
    }

    // ONE toast host for the whole window, over the StackView.
    //
    // Here rather than inside a screen because a toast has to outlive the
    // screen that raised it - "Saved" must stay readable while the user is
    // already navigating away - and because two screens each owning an overlay
    // is how two toasts end up stacked on top of each other.
    StToastHost {
        anchors.fill: parent
    }

    // Sign-in success and session end are reported by the view model, not by
    // the screens: a screen does not know what happens next, and the flow does
    // not know how credentials are checked. See the Connections block above.

    // ---- pre-login flow ---------------------------------------------------

    Component {
        id: splashPage
        SplashScreen {
            onFinished: flow.replace(null, welcomePage)
        }
    }

    Component {
        id: welcomePage
        WelcomeScreen {
            // The design puts a face on this screen. It was rendering an
            // initial because nothing passed the avatar down.
            userName: root.authViewModel.currentUserName.length > 0
                      ? root.authViewModel.currentUserName : qsTr("there")
            avatarSource: root.authViewModel.avatarSource
            onGetStarted: flow.replace(null, loginPage)
        }
    }

    Component {
        id: loginPage
        LoginScreen {
            viewModel: root.authViewModel
            onForgotPassword: flow.push(verifyCodePage)
            // No self-service sign-up: accounts live in a local SQLite file and
            // are provisioned on first run. The link stays because the design
            // has it and hiding it would misrepresent the design; it routes to
            // the same recovery flow rather than to a form that cannot work.
            onSignUpRequested: flow.push(verifyCodePage)
        }
    }

    Component {
        id: verifyCodePage
        VerifyCodeScreen {
            destination: qsTr("the address on this account")
            onVerified: flow.replace(resetPasswordPage)
            onResendRequested: {}
        }
    }

    Component {
        id: resetPasswordPage
        ResetPasswordScreen {
            viewModel: root.authViewModel
            onCompleted: flow.replace(null, loginPage)
        }
    }

    // ---- signed in --------------------------------------------------------

    Component {
        id: shellPage
        ShellScreen {
            id: shell

            viewModel: root.authViewModel
            homeViewModel: root.homeViewModel
            activityModel: root.activityModel
            initialSidebarWidth: root.startupSidebarWidth
            // Pushed up as it changes rather than bound down, so the window
            // holds the last value even after the shell is gone.
            onCurrentSidebarWidthChanged: root.sidebarWidth = shell.currentSidebarWidth
            // signOut() alone: the view model's sessionEnded signal drives the
            // replace, so manual logout and idle lock cannot diverge.
            onLogoutRequested: root.authViewModel.signOut()
        }
    }
}
