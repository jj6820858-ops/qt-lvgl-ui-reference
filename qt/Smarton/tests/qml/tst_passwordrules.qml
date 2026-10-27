import QtQuick
import QtTest
import SmarTon.Ui.Controls

/*!
    StPasswordRules tells people whether a password will be accepted. If it
    disagrees with AuthViewModel::isAcceptablePassword() the form green-ticks a
    password the backend then rejects, so the cases below are deliberately the
    same cases as tst_authviewmodel.cpp.
*/
TestCase {
    id: root
    name: "StPasswordRules"
    width: 400
    height: 200

    Component {
        id: rulesComponent
        StPasswordRules {}
    }

    function test_acceptance_data() {
        return [
            { tag: "empty",            password: "",              acceptable: false },
            { tag: "too short",        password: "Aa1!",          acceptable: false },
            { tag: "no uppercase",     password: "abcdefg1",      acceptable: false },
            { tag: "no lowercase",     password: "ABCDEFG1",      acceptable: false },
            { tag: "no number/symbol", password: "abcdefgH",      acceptable: false },
            { tag: "digit",            password: "abcdefgH1",     acceptable: true  },
            { tag: "symbol",           password: "abcdefgH!",     acceptable: true  },
            { tag: "long",             password: "Correct-Horse1", acceptable: true }
        ];
    }

    function test_acceptance(data) {
        const rules = createTemporaryObject(rulesComponent, root);
        rules.password = data.password;
        compare(rules.acceptable, data.acceptable, data.password);
    }

    function test_metCountTracksRules() {
        const rules = createTemporaryObject(rulesComponent, root);
        rules.password = "";
        compare(rules.metCount, 0);
        rules.password = "abcdefgh";       // length only
        compare(rules.metCount, 1);
        rules.password = "abcdefgH";       // length + case
        compare(rules.metCount, 2);
        rules.password = "abcdefgH1";      // all three
        compare(rules.metCount, 3);
    }
}
