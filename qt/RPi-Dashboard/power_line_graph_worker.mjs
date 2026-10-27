WorkerScript.onMessage = function(queryResult) {
    var points = [];
    var maxValue;

    maxValue = Math.max(...queryResult.map(point => point.data))

    queryResult.forEach((point) => {
                            points.push({x: point.timestamp.getTime(), y: point.data});
                        });

    maxValue = (maxValue + 500) - (maxValue + 500) % 500;

    WorkerScript.sendMessage({ points: points, maxValue: maxValue });
}
