import QtQuick
import QtTest
import SmarTon.Ui.Controls

/*!
    The password field's reveal toggle is a security-relevant control: if
    echoMode ever failed to return to Password, the plaintext would stay on
    screen after the user hid it again.
*/
TestCase {
    id: root
    name: "StTextField"
    when: windowShown
    width: 500
    height: 200

    Component {
        id: fieldComponent
        StTextField {}
    }

    function test_plainFieldIsNotMasked() {
        const field = createTemporaryObject(fieldComponent, root);
        compare(field.echoMode, TextInput.Normal);
    }

    function test_passwordFieldMasksByDefault() {
        const field = createTemporaryObject(fieldComponent, root, { password: true });
        compare(field.echoMode, TextInput.Password);
        verify(!field.revealed);
    }

    function test_revealTogglesBothWays() {
        const field = createTemporaryObject(fieldComponent, root, { password: true });
        field.revealed = true;
        compare(field.echoMode, TextInput.Normal);
        field.revealed = false;
        compare(field.echoMode, TextInput.Password);
    }

    function test_errorTextDrivesErrorState() {
        const field = createTemporaryObject(fieldComponent, root);
        verify(!field.hasError);
        field.errorText = "Passwords do not match";
        verify(field.hasError);
        field.errorText = "";
        verify(!field.hasError);
    }
}
