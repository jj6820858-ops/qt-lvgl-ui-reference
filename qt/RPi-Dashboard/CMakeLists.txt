cmake_minimum_required(VERSION 3.16)

project(rpi-display VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.2 COMPONENTS Quick Charts REQUIRED)
find_package(Qt6 6.2 REQUIRED COMPONENTS Widgets)
find_package(InfluxDB)

qt_add_executable(apprpi-display
    main.cpp
    influxdbdata.h
    influxdbdata.cpp
    influxdbconnection.h
    influxdbconnection.cpp
    influxdbquery.h
    influxdbquery.cpp
    serieshelper.h
    serieshelper.cpp
)

qt_add_qml_module(apprpi-display
    URI rpidisplay
    VERSION 1.0
    QML_FILES main.qml PowerChartView.qml WaterChartView.qml ConsumptionGraphView.qml TemperatureChartView.qml TemperatureSeries.qml water_line_graph_worker.mjs power_line_graph_worker.mjs temperature_line_graph_worker.mjs
    SOURCES     influxdbdata.h influxdbdata.cpp influxdbconnection.h influxdbconnection.cpp influxdbquery.h influxdbquery.cpp serieshelper.h serieshelper.cpp
    RESOURCES img/background.jpg
)

set_target_properties(apprpi-display PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER my.example.com
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(apprpi-display
    PRIVATE Qt6::Quick Qt6::Widgets Qt6::Charts InfluxData::InfluxDB)

install(TARGETS apprpi-display
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
