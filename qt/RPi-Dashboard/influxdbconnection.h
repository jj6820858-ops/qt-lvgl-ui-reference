#ifndef INFLUXDBCONNECTION_H
#define INFLUXDBCONNECTION_H

#include <QObject>
#include <QQueue>
#include <QtQml/qqml.h>
#include <influxdbdata.h>
#include <InfluxDB.h>
#include <influxdbquery.h>
#include <mutex>
#include <condition_variable>
#include <thread>

class InfluxDBConnection : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    QML_ELEMENT
public:
    explicit InfluxDBConnection(QObject *parent = nullptr);
    ~InfluxDBConnection();

    bool connected() const;

    Q_INVOKABLE void connect(const QString &name);
    Q_INVOKABLE InfluxDBQuery* getNewQuery();

signals:
    void connectedChanged();

private:
    void queueQuery(InfluxDBQuery* query);
    void executeQuery(InfluxDBQuery* query);
    void processQueries();

    QList<InfluxDBQuery*> m_queries;
    QQueue<InfluxDBQuery*> m_query_queue;
    bool m_connected = false;
    std::unique_ptr<influxdb::InfluxDB> m_influxDBConnection;
    std::mutex m_queue_mutex;
    std::condition_variable m_cv;
    std::thread m_worker_thread;
    bool m_stop_thread = false;

    friend class InfluxDBQuery;
};

#endif // INFLUXDBCONNECTION_H
