#include "serieshelper.h"
#include <QtCharts/QXYSeries>

SeriesHelper *SeriesHelper::m_instance = nullptr;

SeriesHelper::SeriesHelper(QObject *parent)
    : QObject(parent)
{
}

SeriesHelper *SeriesHelper::instance()
{
    if (!m_instance)
    {
        m_instance = new SeriesHelper();
    }
    return m_instance;
}

void SeriesHelper::replaceSeriesData(QXYSeries *series, const QVariantList &newData)
{
    return replaceSeriesData(series, newData, "x", "y");
}

void SeriesHelper::replaceSeriesData(QXYSeries *series, const QVariantList &newData, const QString xKey, const QString yKey)
{
    if (!series)
        return;

    QVector<QPointF> points;

    for (const QVariant &data : newData)
    {
        QMap point = data.toMap();
        points.append(QPointF(point.value(xKey).toReal(), point.value(yKey).toReal()));
    }

    series->replace(points);
}
