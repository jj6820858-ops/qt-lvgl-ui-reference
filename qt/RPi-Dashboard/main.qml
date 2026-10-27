import QtQuick
import rpidisplay
import QtCharts

Window {
    id: mainWindow
    width: 800
    height: 480
    visible: true
    color: "black"
    title: qsTr("Home Dashboard")

    property int electricityConsumption: 500
    property real waterConsumption: 10
    property real outsideTemperature: -15
    property real insideTemperature: 21

    property InfluxDBQuery electricityQuery: null
    property InfluxDBQuery waterQuery: null
    property InfluxDBQuery outsideTemperatureQuery: null
    property InfluxDBQuery insideTemperatureQuery: null

    InfluxDBConnection {
        id: influx_electricity
    }

    InfluxDBConnection {
        id: influx_water
    }

    InfluxDBConnection {
        id: influx_ruuvi
    }

    PowerChartView {
        id: powerGraphView
        influx_electricity: influx_electricity
    }

    WaterChartView {
        id: waterGraphView
        influx_water: influx_water
    }

    TemperatureChartView {
        id: temperatureGraphView
        influx_ruuvi: influx_ruuvi
        series: [
            TemperatureSeries { name: "Ulkolämpötila"; mac: "CA:39:20:9F:92:AC" },
            TemperatureSeries { name: "Sisälämpötila"; mac: "EF:93:E1:2B:3E:DB" }
        ]
    }

    Component.onCompleted: {
        influx_electricity.connect(powerURL)
        influx_water.connect(waterURL)
        influx_ruuvi.connect(ruuviURL)

        electricityQuery = influx_electricity.getNewQuery()
        electricityQuery.setQuery("select power from consumption order by time desc limit 1")
        electricityQuery.onQueryFinished.connect(function(res) {
            electricityConsumption = res[0].data.toFixed(0)
        });

        waterQuery = influx_water.getNewQuery()
        waterQuery.setQuery("select sum(power) as power from (select difference(first(amount_dl))/10 as power from consumption where time < now() and time >= now()-10m group by time(1m) order by time asc)")
        waterQuery.onQueryFinished.connect(function(res) {
            waterConsumption = res[0] ? res[0].data.toFixed(1) : "--"
        });

        outsideTemperatureQuery = influx_ruuvi.getNewQuery()
        outsideTemperatureQuery.setQuery("select temperature as power from ruuvi_measurements where mac='CA:39:20:9F:92:AC' order by time desc limit 1")
        outsideTemperatureQuery.onQueryFinished.connect(function(res) {
            outsideTemperature = res[0].data.toFixed(1)
        });


        insideTemperatureQuery = influx_ruuvi.getNewQuery()
        insideTemperatureQuery.setQuery("select temperature as power from ruuvi_measurements where mac='EF:93:E1:2B:3E:DB' order by time desc limit 1")
        insideTemperatureQuery.onQueryFinished.connect(function(res) {
            insideTemperature = res[0].data.toFixed(1)
        });
    }

    Timer {
        id: mainWindowTimer
        interval: 500
        triggeredOnStart: true
        running: frontPage.visible
        repeat: true
        onTriggered: {
            refreshAll()
        }
    }

    function refreshAll() {
        refreshQuery(electricityQuery)
        refreshQuery(waterQuery)
        refreshQuery(outsideTemperatureQuery)
        refreshQuery(insideTemperatureQuery)
        refreshDateAndTime()
    }

    function refreshQuery(query) {
        if (query) {
            query.queueQuery()
        }
    }

    function refreshDateAndTime() {
        var date = new Date()
        dateAndTime.text = date.toLocaleString("fi_FI", Locale.LongFormat)
    }

    Rectangle {
        id: rotatingRectangle
        x: 10
        y: 10
        width: 20
        height: 20
        color: "#ADD8E6" // Light blue color
        rotation: 0 // Initial rotation
        smooth: true // Smooth rotation animation

        RotationAnimation {
            id: rotationAnimation
            target: rotatingRectangle
            property: "rotation"
            to: 360
            duration: 5000
            loops: Animation.Infinite // Loop the animation indefinitely
        }

        Component.onCompleted: {
            rotationAnimation.start() // Start the rotation animation when the rectangle is created
        }
    }


    Item {
        id: frontPage

        Image {
            id: image
            x: 0
            y: 0
            width: 800
            height: 480
            opacity: 0.5
            source: "img/background.jpg"
            fillMode: Image.PreserveAspectFit
        }

        Item {
            id: overlay
            x: 0
            y: 0
            width: 800
            height: 480

            Text {
                id: dateAndTime
                color: "#ffffff"
                text: qsTr("Text")
                anchors.top: parent.top
                font.pixelSize: 37
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 50
            }

            Grid {
                id: grid
                width: 650
                height: 300
                rows: 2
                columns: 2
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 40
                anchors.horizontalCenter: parent.horizontalCenter

                Item {
                    id: electricity
                    width: 325
                    height: 150

                    Text {
                        id: fpPower
                        color: "#ffffff"
                        text: "Sähkö: " + electricityConsumption + "W"
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 24
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            powerGraphView.sinceDays = 0
                            powerGraphView.opacity = 1.0
                            frontPage.visible = false
                        }
                    }
                }

                Item {
                    id: insideTemp
                    width: 325
                    height: 150

                    Text {
                        id: fpInsideTemperature
                        color: "#ffffff"
                        text: "Sisälämpötila " + insideTemperature + "℃"
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 24
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            temperatureGraphView.sinceDays = 0
                            temperatureGraphView.opacity = 1.0
                            frontPage.visible = false
                        }
                    }
                }

                Item {
                    id: water
                    width: 325
                    height: 150

                    Text {
                        id: fpWater
                        color: "#ffffff"
                        text: "Vesi: " + waterConsumption + "L / 10min"
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 24
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            waterGraphView.sinceDays = 0
                            waterGraphView.opacity = 1.0
                            frontPage.visible = false
                        }
                    }
                }

                Item {
                    id: outsideTemp
                    width: 325
                    height: 150

                    Text {
                        id: fpOutsideTemperature
                        color: "#ffffff"
                        text: "Ulkolämpötila " + outsideTemperature + "℃"
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 24
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            temperatureGraphView.sinceDays = 0
                            temperatureGraphView.opacity = 1.0
                            frontPage.visible = false
                        }
                    }
                }
            }
        }
    }
}
