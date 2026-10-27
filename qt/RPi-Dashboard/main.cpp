#include <QApplication>
#include <QQmlApplicationEngine>
#include <QCommandLineParser>
#include <QQmlContext>
#include <iostream>
#include <QCursor>
#include <influxdbdata.h>
#include <serieshelper.h>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName("rpi-display");
    QApplication::setApplicationVersion("1.0");
    //QApplication::setOverrideCursor(QCursor(Qt::BlankCursor));

    QCommandLineParser parser;
    parser.setApplicationDescription("Home dashboard application");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption ruuviInfluxConnectionURL(QStringList() << "r" << "ruuvi-url",
            QCoreApplication::translate("main", "Ruuvitag InfluxDB connection URL"),
            QCoreApplication::translate("main", "url"));
    parser.addOption(ruuviInfluxConnectionURL);

    QCommandLineOption waterInfluxConnectionURL(QStringList() << "w" << "water-url",
            QCoreApplication::translate("main", "Water consumption InfluxDB connection URL"),
            QCoreApplication::translate("main", "url"));
    parser.addOption(waterInfluxConnectionURL);

    QCommandLineOption powerInfluxConnectionURL(QStringList() << "p" << "power-url",
            QCoreApplication::translate("main", "Electricity consumption InfluxDB connection URL"),
            QCoreApplication::translate("main", "url"));
    parser.addOption(powerInfluxConnectionURL);

    parser.process(app);
    QString ruuviURL = parser.value(ruuviInfluxConnectionURL);
    QString waterURL = parser.value(waterInfluxConnectionURL);
    QString powerURL = parser.value(powerInfluxConnectionURL);

    qmlRegisterSingletonType<SeriesHelper>("rpidisplay.serieshelper", 1, 0, "SeriesHelper",
        [](QQmlEngine *engine, QJSEngine *scriptEngine) -> QObject * {
            Q_UNUSED(engine)
            Q_UNUSED(scriptEngine)
            return SeriesHelper::instance();
        }
    );

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("ruuviURL", ruuviURL);
    engine.rootContext()->setContextProperty("waterURL", waterURL);
    engine.rootContext()->setContextProperty("powerURL", powerURL);
    const QUrl url(u"qrc:/rpidisplay/main.qml"_qs);
    engine.load(url);

    return app.exec();
}

