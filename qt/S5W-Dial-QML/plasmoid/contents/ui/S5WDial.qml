import QtQuick 2.15
import QtQuick.Shapes 1.15

Item {
    id: "base_dial"

    antialiasing: true

    property real minimum: 0.0
    property real maximum: 50.0
    property int numTicks: 10
    property int elideCount: getElideCount(base_dial.maximum)

    property real value: 50.0
    property string label: "Label"

    // Protect actValue so it's not accessible from outside this object
    QtObject {
        id: d
        property real actValue: Math.min(Math.max(base_dial.minimum, base_dial.value), base_dial.maximum)

        Behavior on actValue {
            NumberAnimation { duration: 800; easing.type: Easing.InOutQuad }
        }
    }

    readonly property real g_zero_scale: -130.0
    readonly property real g_full_scale:  130.0
    readonly property color g_clr_ring: "#242424"

    // Shows a red band for warning/danger areas
    property bool useWarningArea: false
    property real warnLow: 80.0
    property real warnHigh: 100.0

    // Shows a green band for normal operating area
    property bool useDesiredArea: false
    property real desiredLow: 40.0
    property real desiredHigh: 60.0

    // Returns angle in degrees for the given value, where minimum == g_zero_scale
    // and maximum == g_full_scale
    function valueToDegrees(val) {
        var t = (val - minimum) / (maximum - minimum);
        return g_zero_scale + t * (g_full_scale - g_zero_scale);
    }

    function getElideCount(curMax) {
        // How many digits to take off of a value to get a label that will fit
        // in the face?
        var elideCount = 0;
        var reducedMax = curMax;
        while(reducedMax > 1000 && elideCount < 21) {
            elideCount += 3;
            reducedMax /= 1000;
        }

        return elideCount;
    }

    // The face metrics are based around a geometry from (-100, -100) to (100,
    // 100), with the center at (0, 0)
    transform: [
        Translate {
            x: 100
            y: 100
        },
        Scale {
            origin.x: 0
            origin.y: 0
            xScale: Math.min(height, width) / 200
            yScale: Math.min(height, width) / 200
        }
    ]

    Rectangle {
        x: -100
        y: -100
        width: 200
        height: 200
        z: 0

        gradient: Gradient {
            GradientStop { position: 0; color: "#4B4B4B" }
            GradientStop { position: 1; color: "#232323" }
        }

        border.color: "black"
        border.width: 0
        radius: 15
        antialiasing: true
    }

    Shape {
        z: 1

        ShapePath {
            id: "shape_back_outer_ring_fill"

            strokeColor: "transparent"
            fillColor: "white"

            startX: 0
            startY: -98

            PathArc {
                x: -98
                y: 0
                radiusX: 98
                radiusY: 98
                useLargeArc: true
            }

            PathArc {
                x: 0
                y: -98
                radiusX: 98
                radiusY: 98
                useLargeArc: false
            }
        }

        ShapePath {
            id: "shape_desired_band"

            strokeColor: "transparent"
            fillColor: (base_dial.useDesiredArea
                && base_dial.minimum <= base_dial.desiredLow
                && base_dial.maximum >= base_dial.desiredHigh
                && base_dial.desiredLow < base_dial.desiredHigh) ? "limegreen" : "transparent"

            PathAngleArc {
                centerX: 0; centerY: 0
                radiusX: 90; radiusY: 90
                startAngle: valueToDegrees(base_dial.desiredLow) - 90 // 90 deg, not 90 len
                sweepAngle: valueToDegrees(base_dial.desiredHigh) - valueToDegrees(base_dial.desiredLow)
            }

            PathLine {
                x:  98 * Math.sin(valueToDegrees(base_dial.desiredHigh) * Math.PI / 180)
                y: -98 * Math.cos(valueToDegrees(base_dial.desiredHigh) * Math.PI / 180)
            }

            PathAngleArc {
                centerX: 0; centerY: 0
                radiusX: 98; radiusY: 98
                startAngle: valueToDegrees(base_dial.desiredHigh) - 90 // 90 deg, not 90 len
                sweepAngle: valueToDegrees(base_dial.desiredLow) - valueToDegrees(base_dial.desiredHigh)
            }

            PathLine {
                x:  90 * Math.sin(valueToDegrees(base_dial.desiredLow) * Math.PI / 180)
                y: -90 * Math.cos(valueToDegrees(base_dial.desiredLow) * Math.PI / 180)
            }
        }

        ShapePath {
            id: "shape_warning_band"

            strokeColor: "transparent"
            fillColor: (base_dial.useWarningArea
                && base_dial.minimum <= base_dial.warnLow
                && base_dial.maximum >= base_dial.warnHigh
                && base_dial.warnLow < base_dial.warnHigh) ? "red" : "transparent"

            PathAngleArc {
                centerX: 0; centerY: 0
                radiusX: 90; radiusY: 90
                startAngle: valueToDegrees(base_dial.warnLow) - 90 // 90 deg, not 90 len
                sweepAngle: valueToDegrees(base_dial.warnHigh) - valueToDegrees(base_dial.warnLow)
            }

            PathLine {
                x:  98 * Math.sin(valueToDegrees(base_dial.warnHigh) * Math.PI / 180)
                y: -98 * Math.cos(valueToDegrees(base_dial.warnHigh) * Math.PI / 180)
            }

            PathAngleArc {
                centerX: 0; centerY: 0
                radiusX: 98; radiusY: 98
                startAngle: valueToDegrees(base_dial.warnHigh) - 90 // 90 deg, not 90 len
                sweepAngle: valueToDegrees(base_dial.warnLow) - valueToDegrees(base_dial.warnHigh)
            }

            PathLine {
                x:  90 * Math.sin(valueToDegrees(base_dial.warnLow) * Math.PI / 180)
                y: -90 * Math.cos(valueToDegrees(base_dial.warnLow) * Math.PI / 180)
            }
        }
    }

    Shape {
        z: 2
        id: "shape_back_face_ticks"

        ShapePath {
            id: "shape_back_outer_ring"

            strokeColor: "black"
            strokeWidth: 0.7
            fillColor: "transparent"

            startX: 0
            startY: -98

            PathArc {
                x: -98
                y: 0
                radiusX: 98
                radiusY: 98
                useLargeArc: true
            }

            PathArc {
                x: 0
                y: -98
                radiusX: 98
                radiusY: 98
                useLargeArc: false
            }
        }

        function commonGenPathString(min, max, numTicks, markStart, markEnd) {
            if(numTicks < 2 || (Math.abs(max - min) < Number.EPSILON))
                return "z";

            // tickStep in terms of displayed input
            var tickStep = (max - min) / numTicks;

            // start to end deflection in radians
            var radFullDefl = ((g_full_scale - g_zero_scale) * Math.PI / 180.0);
            var radStep = radFullDefl / numTicks;
            var radStart = -radFullDefl / 2; // we're centered around 0
            var radEnd = radFullDefl / 2;

            // the SVG path string
            var svgString = "";

            for(var i = 0; i <= numTicks; i++) {
                var x = radStart + i * radStep;
                // Get new rotation matrix and modify our vector

                var rotMatrix = Qt.matrix4x4(
                    Math.cos(x), -Math.sin(x), 0, 0,
                    Math.sin(x),  Math.cos(x), 0, 0,
                    0          ,  0          , 1, 0,
                    0          ,  0          , 0, 1
                    );

                var pathStart = rotMatrix.times(markStart);
                var pathEnd   = rotMatrix.times(markEnd);

                svgString += "M " + pathStart.x.toFixed(1) + " " + pathStart.y.toFixed(1);
                svgString += "L " + pathEnd.x.toFixed(1)   + " " + pathEnd.y.toFixed(1) + " ";
            }

            svgString += "z";
            return svgString;
        }

        ShapePath {
            id: "shape_back_tick_marks_minor"

            strokeColor: base_dial.g_clr_ring
            strokeWidth: 1.0
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathSvg {
                function genPathString(min, max, numTicks, markStart, markEnd) {
                    return shape_back_face_ticks.commonGenPathString(min, max, numTicks, markStart, markEnd);
                }

                Component.onCompleted: {
                    this.path = Qt.binding(function() {
                        return genPathString(
                            base_dial.minimum,
                            base_dial.maximum,
                            base_dial.numTicks * 4,
                            Qt.vector3d(0.0, -95, 0),
                            Qt.vector3d(0.0, -90.2, 0))
                        });
                }
            }
        }

        ShapePath {
            id: "shape_back_tick_marks"

            strokeColor: "black"
            strokeWidth: 1.6
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathSvg {
                function genPathString(min, max, numTicks, markStart, markEnd) {
                    return shape_back_face_ticks.commonGenPathString(min, max, numTicks, markStart, markEnd);
                }

                Component.onCompleted: {
                    this.path = Qt.binding(function() {
                        return genPathString(
                            base_dial.minimum,
                            base_dial.maximum,
                            base_dial.numTicks,
                            Qt.vector3d(0.0, -98, 0),
                            Qt.vector3d(0.0, -90, 0))
                        });
                }
            }
        }

        ShapePath {
            id: "shape_back_inner_ring"

            strokeColor: base_dial.g_clr_ring
            strokeWidth: 0.9
            fillColor: "transparent"

            startX: 90 * Math.sin(Math.PI * base_dial.g_zero_scale / 180.0)
            startY: -90 * Math.cos(Math.PI * base_dial.g_zero_scale / 180.0)

            PathArc {
                x: -shape_back_inner_ring.startX
                y:  shape_back_inner_ring.startY
                radiusX: 90
                radiusY: 90
                useLargeArc: true
            }
        }

        ShapePath {
            id: "shape_back_label_base"

            strokeColor: "black"
            strokeWidth: 1.0
            fillColor: "white"
            capStyle: ShapePath.FlatCap

            startX: -69.29646
            startY: 69.29646

            PathCubic {
                x: -19; y: 44
                control1X: -52; control1Y: 55;
                control2X: -38; control2Y: 48;
            }

            PathMove {
                x: 19; y: 44
            }

            PathCubic {
                x: -shape_back_label_base.startX; y: shape_back_label_base.startY
                control1X: 38; control1Y: 48;
                control2X: 52; control2Y: 55;
            }
        }

        ShapePath {
            id: "shape_label_base_egg"

            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 80
                x2: 0; y2: 90
                spread: ShapeGradient.ReflectSpread
                GradientStop { position: 0; color: "black" }
                GradientStop { position: 0.5; color: "darkGray" }
                GradientStop { position: 1; color: "black" }
            }

            startX: -57.636
            startY: 79.26

            PathArc {
                x: -shape_label_base_egg.startX; y: shape_label_base_egg.startY
                radiusX: 80; radiusY: 40
                useLargeArc: false
            }

            PathArc {
                x: shape_label_base_egg.startX; y: shape_label_base_egg.startY
                radiusX: 98; radiusY: 98
                useLargeArc: false
            }
        }

        ShapePath {
            id: "shape_label_base_egg_outline"

            strokeColor: "black"
            strokeWidth: 0.7
            fillColor: "transparent"

            startX: -57.636
            startY: 79.26

            PathArc {
                x: -shape_label_base_egg.startX; y: shape_label_base_egg.startY
                radiusX: 80; radiusY: 40
                useLargeArc: false
            }
        }
    }

    Shape {
        id: "shape_needle"
        z: 3

        // Full zero deflection (far left) is -130.0
        // Full max deflection (far right) is 130.0
        // Half-way deflection (middle) is 0.0
        property real deflection: valueToDegrees(d.actValue)

        transform: [
            Rotation { origin.x: 0; origin.y: 0; angle: shape_needle.deflection }
        ]

        ShapePath {
            strokeColor: "darkgray"
            strokeWidth: 0.4

            id: "path_needle"

            fillColor: "#323232"

            startX: 10
            startY: -5

            PathCubic {
                x: 5; y: -69
                control1X: 3; control1Y: -18;
                control2X: 2; control2Y: -57;
            }

            PathCubic {
                x: 0; y: -90
                control1X: 2; control1Y: -77;
                control2X: 1; control2Y: -80;
            }

            PathCubic {
                x: -5; y: -69
                control1X: -1; control1Y: -80;
                control2X: -2; control2Y: -77;
            }

            PathCubic {
                x: -10; y: -5
                control1X: -2; control1Y: -57;
                control2X: -3; control2Y: -18;
            }

            PathLine { x: 10; y: -5 }
        }

        ShapePath {
            strokeColor: "darkgray"
            strokeWidth: 0.4

            startX: 0
            startY: 0

            PathLine { x: 0; y: -84 }
        }
    }

    Shape {
        z: 4
        id: "path_needle_cover"

        ShapePath {
            strokeColor: "black"
            strokeWidth: 0.9

            fillColor: "white"

            startX: -19
            startY: 44

            PathLine { x: -27; y: 8 }

            PathCubic {
                x: 27; y: 8
                control1X: -33; control1Y: -37;
                control2X:  33; control2Y: -37;
            }

            PathLine { x: 19; y: 44 }
        }
    }

    TextMetrics {
        id: "dial_label"

        font.family: 'Noto Sans SemiCondensed'
        font.pointSize: 7
        font.weight: Font.Bold
        elide: Text.ElideMiddle
        elideWidth: 100

        text: base_dial.label
    }

    TextMetrics {
        id: "dial_label_temp"

        font: dial_label.font
        elide: dial_label.elide
        elideWidth: dial_label.elideWidth

        text: ""
    }

    ListModel {
        id: "base_label_model"

        property alias lblText: dial_label.text

        function updateLabelLetters() {
            // Break up input label and assign each letter its (x,y) position
            // and desired rotation

            var radius = 170;
            var max_width = 100
            var height = 46;
            var arcLen = Math.PI * 0.2 * (dial_label.width / max_width); // radians

            base_label_model.clear();

            // Moves the point to the center of our fake circle whose arc we're
            // drawing on top of
            const ptToCenter = Qt.matrix4x4(
                1, 0, 0, 0,
                0, 1, 0, radius + height,
                0, 0, 1, 0,
                0, 0, 0, 1
                );
            const ptToArc = Qt.matrix4x4(
                1, 0, 0, 0,
                0, 1, 0, -1 * radius,
                0, 0, 1, 0,
                0, 0, 0, 1
                );

            for(var i = 0; i < lblText.length; i++) {
                dial_label_temp.text = lblText.substring(0, i);
                var subBoundWidth = dial_label_temp.advanceWidth;
                var theta = (-1 * arcLen / 2) + arcLen * (subBoundWidth / dial_label.advanceWidth);

                const rotMatrix = Qt.matrix4x4(
                    Math.cos(theta), -Math.sin(theta), 0, 0,
                    Math.sin(theta),  Math.cos(theta), 0, 0,
                    0              ,  0              , 1, 0,
                    0              ,  0              , 0, 1
                    );
                const arcMatrix = ptToCenter.times(rotMatrix).times(ptToArc);

                const startPoint = Qt.vector3d(0, 0, 0);
                const rotatedPointAtArc = arcMatrix.times(startPoint);

                // Recalculate metrics for adv:
                dial_label_temp.text = lblText[i];

                var obj = {
                    angle: theta * 180 / Math.PI,
                    itText: lblText[i],
                    adv: dial_label_temp.advanceWidth,
                    itX: rotatedPointAtArc.x,
                    itY: rotatedPointAtArc.y,
                }
                base_label_model.append(obj);
            }
        }

        Component.onCompleted: {
            updateLabelLetters()
        }

        onLblTextChanged: updateLabelLetters()
    }

    Repeater {
        model: base_label_model

        Text {
            x: itX
            y: itY
            z: 3
            rotation: angle
            width: adv
            height: contentHeight
            color: "black"

            font: dial_label.font

            text: itText
        }
    }

    ListModel {
        id: "label_model"

        property alias min: base_dial.minimum
        property alias max: base_dial.maximum
        property alias numTicks: base_dial.numTicks
        property alias elideCount: base_dial.elideCount

        function updateFaceLabels() {
            label_model.clear();

            var tickStep = (base_dial.g_full_scale - base_dial.g_zero_scale) / base_dial.numTicks;
            var valStep  = (base_dial.maximum - base_dial.minimum) / base_dial.numTicks;

            for(var i = 0; i <= base_dial.numTicks; i++) {
                var angle = base_dial.g_zero_scale + i * tickStep;
                var obj = {
                    angle: angle,
                    itText: ((base_dial.minimum + i * valStep) / Math.pow(10, base_dial.elideCount)).toFixed(0),
                }
                label_model.append(obj);
            }
        }

        Component.onCompleted: updateFaceLabels()
        onMinChanged: updateFaceLabels()
        onMaxChanged: updateFaceLabels()
        onElideCountChanged: updateFaceLabels()
        onNumTicksChanged: updateFaceLabels()
    }

    Repeater {
        model: label_model

        Text {
            x: +86.5 * Math.sin(angle * Math.PI / 180.0) - (contentWidth / 2)
               - (Math.sin(angle * Math.PI / 180.0) * (contentWidth / 2))
            y: -86.5 * Math.cos(angle * Math.PI / 180.0) - (contentHeight / 2)
               + (Math.cos(angle * Math.PI / 180.0) * (contentHeight / 2))
            z: 2
            width: contentWidth
            height: contentHeight
            color: "black"

            // Try to reduce height so labels near the top are not so far from
            // edge
            lineHeight: 0.9

            font.family: "Noto Sans Condensed"
            font.pointSize: 7.0
            horizontalAlignment: (angle < -45.0)
                ? Text.AlignLeft  : (angle > 45.0)
                ? Text.AlignRight : Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            text: itText
        }
    }

    Text {
        x: -20
        y: 0
        z: 8
        width: 40
        id: elide_label
        property alias elideCount: base_dial.elideCount
        font.family: "Noto Sans Condensed"
        font.pointSize: 7
        visible: elideCount > 0
        horizontalAlignment: Text.AlignHCenter
        text: generateText(elideCount)

        function generateText(elideCount) {
            // String.replaceAll doesn't work in QML so do it manually
            const replacements = {
                "0": "⁰",
                "1": "¹",
                "2": "²",
                "3": "³",
                "4": "⁴",
                "5": "⁵",
                "6": "⁶",
                "7": "⁷",
                "8": "⁸",
                "9": "⁹",
            };

            // hack to super-script all the strings since rich text format with
            // <sup></sup> doesn't seem to work in QML
            const expoStr = elideCount.toString()
                .split()
                .map(x => replacements[x] ?? x)
                .join();

            return "×10" + expoStr;
        }
    }
}
