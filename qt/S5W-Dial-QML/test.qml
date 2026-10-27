import QtQuick 2.15
import QtQuick.Layouts 1.15

RowLayout {
    spacing: 3
    anchors.fill: parent

    Timer {
        interval: 500
        running: true
        repeat: true

        signal sensorOutput(real val)

        id: cpu_meter
        property real lastTotal: 0
        property real lastUser:  0

        onTriggered: {
            var doc = new XMLHttpRequest();
            doc.onreadystatechange = function() {
                if(doc.readyState !== XMLHttpRequest.DONE) {
                    return;
                }

                var resp = doc.responseText;
                var lines = resp.split("\n");
                var cpu_usage = lines[0].replace(/ +/g, ' ').split(' ').map(i => +i);
                var total =  +cpu_usage[1] + cpu_usage[2] + cpu_usage[3] +
                        cpu_usage[4] + cpu_usage[5] + cpu_usage[6] + cpu_usage[7];
                var user =  +cpu_usage[1] + cpu_usage[2] + cpu_usage[3];

                var user_load = 100.0 * (user - cpu_meter.lastUser) / (total - cpu_meter.lastTotal);

                cpu_meter.sensorOutput(user_load);

                cpu_meter.lastUser = user;
                cpu_meter.lastTotal = total;
            }
            doc.open('GET', '/proc/stat');
            doc.send();
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true

        signal sensorOutput(real val)

        id: mem_avail_meter

        onTriggered: {
            var doc = new XMLHttpRequest();
            doc.onreadystatechange = function() {
                if(doc.readyState !== XMLHttpRequest.DONE) {
                    return;
                }

                var resp = doc.responseText;
                var lines = resp.split("\n");
                var line_re = /^([a-zA-Z_]+): *([0-9]+) /;
                for(var line of lines) {
                    var matchGroup = line_re.exec(line);
                    if(matchGroup && matchGroup[1] === "MemAvailable") {
                        var avail = +matchGroup[2];
                        mem_avail_meter.sensorOutput(avail);
                        break;
                    }
                }
            }

            doc.open('GET', '/proc/meminfo');
            doc.send();
        }
    }

    S5WDial {
        id: base_dial
        minimum: 0.0
        maximum: 100.0

        Layout.minimumHeight: 100
        Layout.minimumWidth: 100
        Layout.fillHeight: true
        Layout.fillWidth: true

        numTicks: 10
        label: "CPU Load (%)"

        useWarningArea: true
        warnLow: 80.0
        warnHigh: 100.0

        Connections {
            target: cpu_meter
            function onSensorOutput(value) {
                base_dial.value = value
            }
        }
    }

    S5WDial {
        id: base_dial_narrow
        minimum: 0.0
        maximum: 40.0

        Layout.minimumHeight: 100
        Layout.minimumWidth: 100
        Layout.fillHeight: true
        Layout.fillWidth: true

        numTicks: 8
        label: "CPU Load NR (%)"

        useDesiredArea: true
        desiredLow: 0.0
        desiredHigh: 10.0

        Connections {
            target: cpu_meter
            function onSensorOutput(value) {
                base_dial_narrow.value = value
            }
        }
    }

    S5WDial {
        id: base_dial_mem
        minimum: 0.0
        maximum: 16.0e6

        Layout.minimumHeight: 100
        Layout.minimumWidth: 100
        Layout.fillHeight: true
        Layout.fillWidth: true

        numTicks: 8
        label: "Mem Avail"

        useDesiredArea: true
        desiredLow: 12.0e6
        desiredHigh: 16.0e6

        useWarningArea: true
        warnLow: 0.0e6
        warnHigh: 2.0e6

        Connections {
            target: mem_avail_meter
            function onSensorOutput(value) {
                base_dial_mem.value = value
            }
        }
    }
}
