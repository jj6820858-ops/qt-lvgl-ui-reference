import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StLineChart
    \inqmlmodule SmarTon.Ui.Components
    \brief Smoothed area chart with axes, a marker and a value callout.
           Figma frame 26.

    Canvas rather than a charting library: the design is one series with a
    specific curve, gradient and callout, and pulling in Qt Charts for that
    would add a module to the embedded image to draw something this file does
    in a hundred lines. Repaint is driven by the properties the drawing reads,
    so scrubbing the marker does not redraw the curve.

    The curve is a Catmull-Rom spline converted to cubic Béziers. A polyline
    through these seven points looks nothing like the design; naive per-segment
    Béziers overshoot into negative values, which on a consumption chart reads
    as generating electricity.
*/
Item {
    id: root

    property var    values: []
    property var    labels: []
    property string unit: qsTr("kW")
    property int    selectedIndex: -1

    /*! Axis maximum, rounded up to a friendly step above the data. */
    readonly property real axisMax: {
        let peak = 0;
        for (const value of root.values)
            peak = Math.max(peak, value);
        if (peak <= 0)
            return 20;
        const step = Math.pow(10, Math.floor(Math.log(peak) / Math.LN10)) / 2;
        return Math.ceil(peak / step) * step;
    }

    readonly property int gridLines: 4
    readonly property int axisWidth: 62
    readonly property int labelHeight: 34

    signal pointSelected(int index)

    implicitHeight: 320

    // ---- y axis -----------------------------------------------------------
    Repeater {
        model: root.gridLines + 1

        delegate: Item {
            id: gridLine

            required property int index

            /*! 1 at the top of the plot, 0 at the baseline. */
            readonly property real fraction: 1 - gridLine.index / root.gridLines

            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            y: root.labelHeight
               + (root.height - root.labelHeight * 2) * (gridLine.index / root.gridLines)

            StLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.axisWidth - Theme.spacing3
                horizontalAlignment: Text.AlignRight
                text: qsTr("%1 %2")
                        .arg(Math.round(root.axisMax * gridLine.fraction))
                        .arg(root.unit)
                level: 1
                tone: "muted"
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: root.axisWidth
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Theme.outline
                opacity: 0.35
            }
        }
    }

    // ---- plot -------------------------------------------------------------
    Canvas {
        id: plot

        anchors.left: parent.left
        anchors.leftMargin: root.axisWidth
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.labelHeight
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.labelHeight
        antialiasing: true

        readonly property var series: root.values
        readonly property real ceiling: root.axisMax
        onSeriesChanged: plot.requestPaint()
        onCeilingChanged: plot.requestPaint()

        function pointX(index: int): real {
            const count = plot.series.length;
            if (count <= 1)
                return 0;
            return (plot.width / (count - 1)) * index;
        }

        function pointY(index: int): real {
            if (plot.ceiling <= 0)
                return plot.height;
            return plot.height * (1 - plot.series[index] / plot.ceiling);
        }

        onPaint: {
            const ctx = plot.getContext("2d");
            ctx.reset();
            const count = plot.series.length;
            if (count < 2)
                return;

            // Catmull-Rom -> cubic Bézier. Keeps the curve through every data
            // point without the overshoot a naive smoothing would produce.
            const path = [];
            for (let i = 0; i < count; ++i)
                path.push({ x: plot.pointX(i), y: plot.pointY(i) });

            const trace = function () {
                ctx.moveTo(path[0].x, path[0].y);
                for (let i = 0; i < count - 1; ++i) {
                    const p0 = path[Math.max(0, i - 1)];
                    const p1 = path[i];
                    const p2 = path[i + 1];
                    const p3 = path[Math.min(count - 1, i + 2)];
                    ctx.bezierCurveTo(
                        p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6,
                        p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6,
                        p2.x, p2.y);
                }
            };

            // Fill under the curve first, so the stroke sits on top of it.
            const gradient = ctx.createLinearGradient(0, 0, 0, plot.height);
            gradient.addColorStop(0, Qt.rgba(0.07, 0.25, 0.50, 0.55));
            gradient.addColorStop(1, Qt.rgba(0.07, 0.25, 0.50, 0.0));
            ctx.beginPath();
            trace();
            ctx.lineTo(path[count - 1].x, plot.height);
            ctx.lineTo(path[0].x, plot.height);
            ctx.closePath();
            ctx.fillStyle = gradient;
            ctx.fill();

            ctx.beginPath();
            trace();
            ctx.strokeStyle = Theme.primary;
            ctx.lineWidth = 2.5;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.stroke();
        }

        // Scrub target. A tap anywhere picks the nearest point rather than
        // demanding a hit on a 6 px marker, which no finger can do.
        TapHandler {
            onTapped: function (point) {
                const count = plot.series.length;
                if (count < 2)
                    return;
                const step = plot.width / (count - 1);
                root.pointSelected(Math.max(0, Math.min(count - 1,
                                            Math.round(point.position.x / step))));
            }
        }
    }

    // ---- selection band, marker and callout -------------------------------
    Item {
        id: marker

        readonly property bool active:
            root.selectedIndex >= 0 && root.selectedIndex < root.values.length

        visible: marker.active
        x: plot.x + (marker.active ? plot.pointX(root.selectedIndex) : 0)
        y: plot.y + (marker.active ? plot.pointY(root.selectedIndex) : 0)
        width: 1
        height: 1

        // Vertical highlight behind the selected column.
        Rectangle {
            x: -28
            y: plot.y - marker.y
            width: 56
            height: plot.height
            color: Theme.textPrimary
            opacity: 0.04
        }

        Rectangle {
            anchors.centerIn: parent
            width: 20
            height: 20
            radius: 10
            color: Theme.textPrimary

            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 10
                radius: 5
                color: Theme.primary
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: Theme.spacing4
            width: callout.implicitWidth + Theme.spacing5 * 2
            height: 42
            radius: Theme.radiusSm
            color: Theme.textPrimary

            StLabel {
                id: callout
                anchors.centerIn: parent
                text: marker.active
                      ? qsTr("%1 %2").arg(Math.round(root.values[root.selectedIndex])).arg(root.unit)
                      : ""
                level: 2
                color: Theme.surfaceDeep
                font.weight: Theme.fontWeightBold
            }
        }
    }

    // ---- x axis -----------------------------------------------------------
    Repeater {
        model: root.labels

        delegate: StLabel {
            required property int index
            required property var modelData

            x: plot.x + plot.pointX(index) - width / 2
            y: root.height - root.labelHeight + Theme.spacing2
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: modelData
            level: 1
            tone: "muted"
        }
    }
}
