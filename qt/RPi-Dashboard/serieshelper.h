#ifndef SERIESHELPER_H
#define SERIESHELPER_H

#include <QObject>
#include <QtCharts/QXYSeries>

class SeriesHelper : public QObject
{
    Q_OBJECT
public:
    static SeriesHelper *instance();

    Q_INVOKABLE void replaceSeriesData(QXYSeries *series, const QVariantList &newData);
    Q_INVOKABLE void replaceSeriesData(QXYSeries *series, const QVariantList &newData, const QString xKey, const QString yKey);

private:
    explicit SeriesHelper(QObject *parent = nullptr);
    static SeriesHelper *m_instance;
};

#endif // SERIESHELPER_H
