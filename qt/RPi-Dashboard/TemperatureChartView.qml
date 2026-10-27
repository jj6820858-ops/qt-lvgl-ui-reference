import QtQuick
import rpidisplay
import QtCharts
import rpidisplay.serieshelper

Item {
    id: root
    required property InfluxDBConnection influx_ruuvi
    required property list<TemperatureSeries> series
    property int sinceDays: 0
    opacity: 0.0
    property list<InfluxDBQuery> queries
    property list<LineSeries> lineSeries
    property int minValue: 0
    property int maxValue: 0
    property double maxSeriesValue: 0
    property double minSeriesValue: 0

    WorkerScript {
        id: lineGraphWorker
        source: "temperature_line_graph_worker.mjs"

        onMessage: function(messageObject) {
            SeriesHelper.replaceSeriesData(lineSeries[messageObject.seriesNum], messageObject.points)

            maxSeriesValue = Math.max(messageObject.maxValue, maxSeriesValue)
            minSeriesValue = Math.min(messageObject.minValue, minSeriesValue)

            if (messageObject.seriesNum >= messageObject.seriesLength - 1) {
                minValue = minSeriesValue - 2
                maxValue = maxSeriesValue + 2
            }

        }
    }

    function createInitialSeries(series) {
        var lineSerie = chartView.createSeries(ChartView.SeriesTypeLine, series.name, timeAxis, yAxis);
        lineSeries.push(lineSerie);
    }

    function createSeriesQuery(index) {
        var seriesQuery = influx_ruuvi.getNewQuery()

        var onQueryFinished = function(queryResult) {
            onSeriesQueryFinished(queryResult, index, series.length)
        }

        seriesQuery.onQueryFinished.connect(onQueryFinished);
        queries.push(seriesQuery)
    }

    Component.onCompleted: {
        for (var i = 0; i < series.length; i++) {
            createInitialSeries(series[i])
            createSeriesQuery(i)
        }
    }

    function onSeriesQueryFinished(queryResult, seriesNum, seriesLength) {
        var updatedSeries = chartView.series(seriesNum)
        var message = { queryResult: queryResult, seriesNum: seriesNum, seriesLength: seriesLength };
        lineGraphWorker.sendMessage(message);
    }

    function refresh(sinceDays) {
        maxSeriesValue = 0
        minSeriesValue = 0

        var endOfDay = new Date()
        endOfDay.setHours(0,0,0,0)
        endOfDay.setDate(endOfDay.getDate() + 1)

        var startTime = new Date(endOfDay)
        var endTime = new Date(endOfDay)
        startTime.setDate(endOfDay.getDate() - (sinceDays+1))
        endTime.setDate(endOfDay.getDate() - (sinceDays))

        timeAxis.max = endTime
        timeAxis.min = startTime
        timeAxis.tickCount = 25

        for (var i = 0; i < series.length; i++) {
            var updatedSeries = chartView.series(i)
            updatedSeries.clear()
            var mac = series[i].mac

            var queryText = "select mean(temperature) as power from ruuvi_measurements where mac='" + mac + "' and time >= '" + endOfDay.toJSON() + "' - " + (sinceDays+1) + "d and time < '" + endOfDay.toJSON() + "' - " + sinceDays + "d group by time(10m) order by time asc"
            queries[i].setQuery(queryText)
            queries[i].queueQuery()
        }

        var titleDate = new Date()
        titleDate.setDate(titleDate.getDate() - sinceDays)
        chartView.title = "Lämpötila " + titleDate.toLocaleDateString("fi_FI")
        chartView.focus = true
    }

    Rectangle {
        id: temperatureGraphView
        color: mainWindow.color
        width: mainWindow.width
        height: mainWindow.height
        opacity: parent.opacity
        visible: opacity != 0

        onVisibleChanged: {
            if (visible) {
                refresh(0)
            }
        }

        ChartView {
            id: chartView
            title: "Lämpötila"
            anchors.fill: parent
            antialiasing: true
            theme: ChartView.ChartThemeDark
            legend.visible: true

            ValuesAxis {
                id: yAxis
                min: minValue
                max: maxValue
                tickCount: 11
                minorTickCount: 1

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
}
