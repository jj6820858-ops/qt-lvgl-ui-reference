import QtQuick
import SmarTon.Ui.Theme

/*!
    \qmltype StRuler
    \inqmlmodule SmarTon.Ui.Controls
    \brief Tick-ruler value picker. Figma frame 14, room size.

    Drag to scrub. Reads as a physical measuring tape rather than a slider,
    which is why the design uses it for a size: the ticks give a sense of
    scale that a bare track does not.

    Ticks are drawn on one Canvas rather than instantiated as items. At two
    ticks per unit over a 500-unit range that is a thousand Rectangles, each
    with its own bindings and its own node - a Canvas is one node.
*/
Item {
    id: root

    property real from: 1
    property real to: 60
    property real value: 20

    signal moved(real value)

    implicitHeight: 68

    property string accessibleName: qsTr("Size")

    Accessible.role: Accessible.Slider
    Accessible.name: root.accessibleName
    Accessible.description: String(Math.round(root.value))

    function valueAt(x: real): real {
        const fraction = Math.max(0, Math.min(1, x / Math.max(1, root.width)));
        return Math.round(root.from + fraction * (root.to - root.from));
    }

    Canvas {
        id: ticks

        anchors.fill: parent
        antialiasing: true

        readonly property real current: root.value
        onCurrentChanged: ticks.requestPaint()
        onWidthChanged: ticks.requestPaint()

        onPaint: {
            const ctx = ticks.getContext("2d");
            ctx.reset();

            const span = Math.max(1, root.to - root.from);
            const count = Math.round(span);
            const step = ticks.width / count;
            const midY = ticks.height / 2;

            for (let i = 0; i <= count; ++i) {
                const x = i * step;
                // Every fifth tick is taller, as on a real rule.
                const tall = i % 5 === 0;
                const half = tall ? 22 : 13;
                ctx.beginPath();
                ctx.strokeStyle = Theme.textMuted;
                ctx.globalAlpha = tall ? 0.85 : 0.45;
                ctx.lineWidth = 1.5;
                ctx.moveTo(x, midY - half);
                ctx.lineTo(x, midY + half);
                ctx.stroke();
            }

            // The cursor.
            const cursorX = ((ticks.current - root.from) / span) * ticks.width;
            ctx.beginPath();
            ctx.strokeStyle = Theme.primary;
            ctx.globalAlpha = 1;
            ctx.lineWidth = 3;
            ctx.lineCap = "round";
            ctx.moveTo(cursorX, midY - 26);
            ctx.lineTo(cursorX, midY + 26);
            ctx.stroke();
        }
    }

    TapHandler {
        onTapped: point => root.moved(root.valueAt(point.position.x))
    }

    DragHandler {
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onCentroidChanged: {
            if (active)
                root.moved(root.valueAt(centroid.position.x));
        }
    }
}
