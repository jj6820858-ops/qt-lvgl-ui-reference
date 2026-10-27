import QtQuick
import QtTest
import SmarTon.Ui.Controls

/*!
    StOtpField is the only control in SmarTon that moves focus on the user's
    behalf, which makes it the one most likely to strand someone mid-entry.
    These tests pin the behaviour that makes it usable: forward on entry,
    backward on backspace, and a complete() signal that fires exactly once.
*/
TestCase {
    id: root
    name: "StOtpField"
    when: windowShown
    width: 400
    height: 200

    Component {
        id: otpComponent
        StOtpField {}
    }

    function test_startsEmptyAndIncomplete() {
        const otp = createTemporaryObject(otpComponent, root);
        compare(otp.code, "");
        verify(!otp.complete);
    }

    function test_typingFillsCellsAndCompletes() {
        const otp = createTemporaryObject(otpComponent, root);
        const spy = createTemporaryObject(spyComponent, root, { target: otp });

        keyClick(Qt.Key_1);
        keyClick(Qt.Key_2);
        keyClick(Qt.Key_3);
        compare(otp.code, "123");
        verify(!otp.complete);
        compare(spy.count, 0);

        keyClick(Qt.Key_4);
        compare(otp.code, "1234");
        verify(otp.complete);
        // Exactly one emission: a second would re-trigger whatever the screen
        // wired to it, and "verify this code" is not an idempotent action.
        tryCompare(spy, "count", 1, 1000);
    }

    function test_nonDigitsAreRejected() {
        const otp = createTemporaryObject(otpComponent, root);
        keyClick(Qt.Key_A);
        compare(otp.code, "");
    }

    function test_backspaceRetreatsAndClears() {
        const otp = createTemporaryObject(otpComponent, root);
        keyClick(Qt.Key_1);
        keyClick(Qt.Key_2);
        compare(otp.code, "12");

        // The cursor is parked on the empty third cell, so one backspace steps
        // back and clears the "2"; a second clears the "1".
        keyClick(Qt.Key_Backspace);
        compare(otp.code, "1");
        keyClick(Qt.Key_Backspace);
        compare(otp.code, "");
    }

    function test_clearResetsEverything() {
        const otp = createTemporaryObject(otpComponent, root);
        keyClick(Qt.Key_1);
        keyClick(Qt.Key_2);
        keyClick(Qt.Key_3);
        keyClick(Qt.Key_4);
        otp.clear();
        compare(otp.code, "");
        verify(!otp.complete);
    }

    Component {
        id: spyComponent
        SignalSpy { signalName: "completed" }
    }
}
