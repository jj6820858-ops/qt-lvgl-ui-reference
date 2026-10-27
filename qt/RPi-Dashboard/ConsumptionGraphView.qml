import QtQuick
import QtCharts

Rectangle {
    id: consumptionGraphView
    color: mainWindow.color
    width: mainWindow.width
    height: mainWindow.height
    opacity: parent.opacity
    visible: opacity != 0

    property alias chartView: chartView
    property alias lineSeries: lineSeries
    property alias barSeries: barSeries
    property alias timeAxis: timeAxis
    property alias barAxis: barAxis
    property alias yAxis: yAxis

    onVisibleChanged: {
        if (visible) {
            refresh(0)
        }
    }

    ChartView {
        id: chartView
        title: "Veden kulutus"
        anchors.fill: parent
        antialiasing: true
        theme: ChartView.ChartThemeDark
        legend.visible: false

        BarSeries {
            useOpenGL: true
            id: barSeries
            axisX: barAxis
            axisY: yAxis
        }

        LineSeries {
            useOpenGL: true
            id: lineSeries
            axisX: timeAxis
            axisY: yAxis
        }

        ValuesAxis {
            id: yAxis
            min: 0
            max: 10000
            tickCount: 11
            minorTickCount: 1

        }

        BarCategoryAxis {
            id: barAxis
            gridVisible: false
            lineVisible: false
            labelsVisible: false
            titleVisible: false

        }

        DateTimeAxis {
            id: timeAxis
            format: "hh:mm"
            labelsAngle: 45
            truncateLabels: false
            minorGridVisible: true
        }

        MouseArea {
            id: mouseArealeft
            width: 266
            height: 480
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 0
            anchors.leftMargin: 0

            onClicked: {
                sinceDays = sinceDays + 1
                refresh(sinceDays)
            }
        }

        MouseArea {
            id: mouseAreaMiddle
            width: 268
            height: 480
            anchors.left: mouseArealeft.right
            anchors.top: mouseArealeft.top
            anchors.topMargin: 0
            anchors.leftMargin: 0

            onClicked: {
                root.opacity = 0.0
                frontPage.visible = true
            }
        }

        MouseArea {
            id: mouseAreaRight
            width: 266
            height: 480
            anchors.left: mouseAreaMiddle.right
            anchors.top: mouseAreaMiddle.top
            anchors.topMargin: 0
            anchors.leftMargin: 0

            onClicked: {
                if (sinceDays > 0) {
                    sinceDays = sinceDays - 1
                }
                refresh(sinceDays)
            }
        }

        Keys.onLeftPressed: {
            sinceDays = sinceDays + 1
            refresh(sinceDays)
        }

        Keys.onRightPressed: {
            if (sinceDays > 0) {
                sinceDays = sinceDays - 1
            }
            refresh(sinceDays)
        }
    }
}
