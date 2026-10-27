#ifndef INFLUXDBQUERY_H
#define INFLUXDBQUERY_H

#include <QObject>
#include <mutex>
#include <QtQml/qqml.h>

class InfluxDBConnection;

class InfluxDBQuery : public QObject
{
    Q_OBJECT
    QML_ELEMENT
public:
    InfluxDBQuery(InfluxDBConnection *connection = nullptr);

    Q_INVOKABLE void setQuery(const QString query);
    Q_INVOKABLE void queueQuery();
    QString getQuery();

signals:
    void queryFinished(QVariantList result);

public slots:
    void setQueryResult(QVariantList result);

private:
    QString m_query;
    QVariantList m_result;
    InfluxDBConnection *m_connection;

};

#endif // INFLUXDBQUERY_H
