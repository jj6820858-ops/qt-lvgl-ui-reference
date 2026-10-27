WorkerScript.onMessage = function(queryResult) {
    var points = [];
    var firstValue;
    var maxValue;

    if (queryResult[0]) {
        firstValue = queryResult[0].data
        maxValue = queryResult[queryResult.length - 1].data - firstValue
        maxValue = maxValue / 10

        // Sometimes water meter maximum value can go haywire because of bad data,
        // make sure the maximum value makes some sense
        if (maxValue > 2000 || maxValue < 0) {
            maxValue = 600
        }

        queryResult.forEach((point) => {
                                points.push({x: point.timestamp.getTime(), y: (point.data-firstValue)/10});
                    });

        maxValue = (maxValue + 50) - (maxValue + 50) % 50
    }

    WorkerScript.sendMessage({ points: points, maxValue: maxValue });
}
