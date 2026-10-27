import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StDial
    \inqmlmodule SmarTon.Ui.Controls
    \brief Circular thermostat dial. Figma frame 22.

    MEASURED, not eyeballed. From the frame at 1440x1024: outer disc ⌀345 and
    inner disc ⌀258 about the same centre - so the ring is 12.6% of the
    diameter on each side - eight #D9DFE6 marker dots on a radius 0.609 of the
    outer, at exact 45° intervals starting at twelve o'clock. Everything below
    is expressed as a RATIO of \\l size rather than as those pixel numbers, so
    the dial is correct at the 1024-wide panel size as well as at the frame's.

    THE SCALE IS CHOSEN, NOT COPIED, and that is worth being explicit about.
    The frame shows 24°C with the handle at 57° from top. No consistent
    mapping of a sensible temperature range onto a 360° sweep puts 24 at 57°,
    so the handle in the mock is placed for looks rather than plotted. Copying
    its angle would mean a dial that reads correctly at exactly one value and
    lies at every other. So the geometry matches the frame and the SCALE is
    the honest one: \\l from..\\l to spread over the full circle, with the eight
    dots landing on eighths of the range.

    DRAG ANYWHERE, not just on the handle. A 22px target on a touch panel is
    the difference between a control and a puzzle, so the whole ring responds
    and the handle is an indicator rather than a grab point.
*/
Item {
    id: root

    property int from: 16
    property int to: 30
    property int value: 24
    /*! Suffix drawn after the number, smaller and raised. */
    property string unit: "°C"
    property bool interactive: true

    /*! Emitted while dragging AND on release, like every other control here -
        a thermostat that only reports at the end feels broken, and the caller
        can throttle if it needs to. */
    signal moved(int value)

    readonly property int size: Math.min(root.width, root.height)
    readonly property real outerRadius: root.size / 2
    /*! Measured: 258/345 of the outer. */
    readonly property real innerRadius: root.outerRadius * 0.748
    /*! Measured: dots at 105 of a 172.5 outer radius. */
    readonly property real markerRadius: root.outerRadius * 0.609

    readonly property real _span: Math.max(1, root.to - root.from)
    readonly property real _fraction: Math.max(0, Math.min(1,
        (root.value - root.from) / root._span))
    /*! Degrees clockwise from twelve o'clock. */
    readonly property real _angle: root._fraction * 360

    implicitWidth: 320
    implicitHeight: 320

    Accessible.role: Accessible.Dial
    Accessible.name: qsTr("Target temperature")
    Accessible.description: qsTr("%1 degrees").arg(root.value)

    function _pointOnRing(degrees: real, radius: real): point {
        const rad = (degrees - 90) * Math.PI / 180;
        return Qt.point(root.width / 2 + radius * Math.cos(rad),
                        root.height / 2 + radius * Math.sin(rad));
    }

    /*! Nearest legal value for a point, used by both drag and tap. */
    function _valueAt(x: real, y: real): int {
        const dx = x - root.width / 2;
        const dy = y - root.height / 2;
        // atan2 gives -180..180 from the +x axis; shift so 0 is twelve
        // o'clock and the result runs clockwise, which is how the dial reads.
        let deg = Math.atan2(dy, dx) * 180 / Math.PI + 90;
        if (deg < 0)
            deg += 360;
        return Math.round(root.from + (deg / 360) * root._span);
    }

    function _apply(x: real, y: real): void {
        const next = Math.max(root.from, Math.min(root.to, root._valueAt(x, y)));
        if (next !== root.value)
            root.moved(next);
    }

    // ---- ring ---------------------------------------------------------------
    Rectangle {
        id: ring

        anchors.centerIn: parent
        width: root.size
        height: root.size
        radius: width / 2
        antialiasing: true
        // Measured #606974 - between outline and outlineStrong, and closer to
        // neither than to the value halfway between them, so it is its own
        // token rather than an approximation of an existing one.
        color: Theme.dialRing
    }

    // The progress arc, drawn on the ring's centreline. A Canvas because QML
    // has no arc primitive and the alternative - a rotated Rectangle mask - is
    // three items and worse antialiasing. Repainted only when the value or the
    // size changes, never per frame.
    Canvas {
        id: arc

        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = arc.getContext("2d");
            ctx.reset();
            const cx = root.width / 2;
            const cy = root.height / 2;
            const r = (root.outerRadius + root.innerRadius) / 2;
            const thickness = root.outerRadius - root.innerRadius;

            ctx.lineCap = "round";
            ctx.lineWidth = thickness * 0.30;
            ctx.strokeStyle = Theme.dialTrack;
            ctx.beginPath();
            // -90 puts zero at twelve o'clock, matching _pointOnRing.
            ctx.arc(cx, cy, r, -Math.PI / 2,
                    -Math.PI / 2 + root._fraction * Math.PI * 2, false);
            ctx.stroke();
        }
    }

    // ---- marker dots ---------------------------------------------------------
    Repeater {
        model: 8

        delegate: Rectangle {
            id: marker

            required property int index

            readonly property point at: root._pointOnRing(marker.index * 45,
                                                          root.markerRadius)
            // Measured ⌀8 on a 345 dial.
            width: Math.max(4, root.size * 0.023)
            height: width
            radius: width / 2
            x: marker.at.x - width / 2
            y: marker.at.y - height / 2
            antialiasing: true
            color: Theme.textSecondary
            // The marker the handle is nearest lights up. Without it the dots
            // are decoration; with it they are a scale.
            opacity: Math.abs(root._angle - marker.index * 45) < 22.5 ? 1.0 : 0.45
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }
    }

    // ---- face ----------------------------------------------------------------
    Rectangle {
        anchors.centerIn: parent
        width: root.innerRadius * 2
        height: width
        radius: width / 2
        antialiasing: true
        color: Theme.background          // measured #202326

        Row {
            anchors.centerIn: parent
            spacing: 0

            StLabel {
                text: String(root.value)
                level: 4
                tone: "brand"
                anchors.verticalCenter: parent.verticalCenter
            }

            StLabel {
                text: root.unit
                level: 3
                tone: "brand"
                // Raised to sit against the cap height, the way a degree sign
                // is set - baseline-aligned it reads as a separate word.
                anchors.top: parent.top
                anchors.topMargin: root.size * 0.045
            }
        }
    }

    // ---- handle ---------------------------------------------------------------
    Rectangle {
        id: handle

        readonly property point at: root._pointOnRing(
            root._angle, (root.outerRadius + root.innerRadius) / 2)

        width: root.size * 0.075
        height: width
        radius: width / 2
        x: handle.at.x - width / 2
        y: handle.at.y - height / 2
        antialiasing: true
        color: Theme.primary
        border.width: drag.active ? Theme.borderWidthFocus : 0
        border.color: Theme.textPrimary
        scale: drag.active ? 1.15 : 1.0

        Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
    }

    // ---- input -----------------------------------------------------------------
    DragHandler {
        id: drag

        enabled: root.interactive
        target: null                  // we position the handle ourselves
        onCentroidChanged: {
            if (drag.active)
                root._apply(drag.centroid.position.x, drag.centroid.position.y);
        }
    }

    TapHandler {
        enabled: root.interactive
        onSingleTapped: function (point) {
            root._apply(point.position.x, point.position.y);
        }
    }

    // A dial that can only be set by dragging is unusable with a keyboard, and
    // this panel ships with one attached.
    focus: root.interactive
    activeFocusOnTab: root.interactive
    Keys.onUpPressed: root.moved(Math.min(root.to, root.value + 1))
    Keys.onRightPressed: root.moved(Math.min(root.to, root.value + 1))
    Keys.onDownPressed: root.moved(Math.max(root.from, root.value - 1))
    Keys.onLeftPressed: root.moved(Math.max(root.from, root.value - 1))

    onValueChanged: arc.requestPaint()
    onWidthChanged: arc.requestPaint()
    onHeightChanged: arc.requestPaint()
}
