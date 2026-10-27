import QtQuick
import rpidisplay
import rpidisplay.serieshelper

Item {
    required property InfluxDBConnection influx_water
    opacity: 0.0
    id: root
    property int sinceDays: 0
    property InfluxDBQuery waterLineChartQuery: null
    property InfluxDBQuery waterBarChartQuery: null

    WorkerScript {
        id: lineGraphWorker
        source: "water_line_graph_worker.mjs"

        onMessage: function(messageObject) {
            SeriesHelper.replaceSeriesData(consumptionGraphView.lineSeries, messageObject.points)
            consumptionGraphView.yAxis.max = messageObject.maxValue;
        }
    }

    ConsumptionGraphView {
        id: consumptionGraphView

        Component.onCompleted: {
            waterLineChartQuery = influx_water.getNewQuery()
            waterLineChartQuery.onQueryFinished.connect(onWaterLineChartQueryFinished)
            waterBarChartQuery = influx_water.getNewQuery()
            waterBarChartQuery.onQueryFinished.connect(onWaterBarChartQueryFinished)
        }

        function onWaterLineChartQueryFinished(queryResult) {
            lineGraphWorker.sendMessage(queryResult);
        }

        function onWaterBarChartQueryFinished(queryResult) {
            barSeries.visible = false;
            barSeries.clear()
            if (queryResult[0]) {
                barSeries.append("litersPerHour", queryResult.map(point => point.data))
            }
            barSeries.visible = true;
        }

        function refresh(sinceDays) {
            barAxis.categories = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24"]

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

            // Cumulative consumption in the last 24 hours
            var queryText = "select last(amount_dl) as power from consumption where time >= '" + endOfDay.toJSON() + "' - " + (sinceDays+1) + "d and time < '" + endOfDay.toJSON() + "' - " + sinceDays + "d group by time(2m) order by time asc"
            waterLineChartQuery.setQuery(queryText)
            waterLineChartQuery.queueQuery();

            queryText = "select difference(last(amount_dl))/10 as power from consumption where time >= '" + endOfDay.toJSON() + "' - " + (sinceDays+1) + "d and time < '" + endOfDay.toJSON() + "' - " + sinceDays + "d + 1s group by time(1h) order by time asc"
            waterBarChartQuery.setQuery(queryText)
            waterBarChartQuery.queueQuery()

            var titleDate = new Date()
            titleDate.setDate(titleDate.getDate() - sinceDays)
            chartView.title = "Veden kulutus " + titleDate.toLocaleDateString("fi_FI")
            chartView.focus = true
        }
    }
}
