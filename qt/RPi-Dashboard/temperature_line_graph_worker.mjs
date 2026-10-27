WorkerScript.onMessage = function(message) {
    var queryResult = message.queryResult;
    var seriesNum = message.seriesNum;
    var seriesLength = message.seriesLength;
    var points = [];
    var maxValue;
    var minValue;

    queryResult.forEach((point) => {
                            points.push({x: point.timestamp.getTime(), y: point.data})
                        });

    maxValue = Math.max(...queryResult.map(point => point.data))
    minValue = Math.min(...queryResult.map(point => point.data))

    WorkerScript.sendMessage({ points: points, maxValue: maxValue, minValue: minValue, seriesNum: seriesNum, seriesLength: seriesLength });
}
