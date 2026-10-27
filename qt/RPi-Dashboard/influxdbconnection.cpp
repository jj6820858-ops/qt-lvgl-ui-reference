#include "influxdbconnection.h"

#include <InfluxDBFactory.h>
#include <influxdbquery.h>
#include <iostream>

InfluxDBConnection::InfluxDBConnection(QObject *parent)
    : QObject{parent}
{
    m_worker_thread = std::thread(&InfluxDBConnection::processQueries, this);
}

InfluxDBConnection::~InfluxDBConnection()
{
    m_stop_thread = true;
    m_cv.notify_one();
    m_worker_thread.join();
}

bool InfluxDBConnection::connected() const
{
    return m_connected;
}

void InfluxDBConnection::connect(const QString &url)
{
    if (m_connected == false) {
        std::cout << "Not connected, connecting" << std::endl;
        m_influxDBConnection = influxdb::InfluxDBFactory::Get(url.toStdString());
        m_connected = true;
        emit connectedChanged();
    }
}

InfluxDBQuery* InfluxDBConnection::getNewQuery()
{
    InfluxDBQuery* query = new InfluxDBQuery(this);
    m_queries.append(query);
    return query;
}

void InfluxDBConnection::queueQuery(InfluxDBQuery *query)
{
    {
        std::lock_guard lk(m_queue_mutex);
        m_query_queue.enqueue(query);
    }
    m_cv.notify_one();
}

void InfluxDBConnection::executeQuery(InfluxDBQuery *query)
{
    auto data = m_influxDBConnection->query(query->getQuery().toStdString());
    QVariantList result;
    for (auto element : data) {
        InfluxDBData new_element;
        new_element.setData(QString::fromStdString(element.getFields()).remove(0,6).toDouble());
        long value_ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::time_point_cast<std::chrono::milliseconds>(element.getTimestamp()).time_since_epoch()).count();
        new_element.setTimestamp(QDateTime::fromMSecsSinceEpoch(value_ms));
        result.append(QVariant::fromValue(new_element));
    }

    query->setQueryResult(result);
}

void InfluxDBConnection::processQueries()
{
    while (!m_stop_thread) {
        std::unique_lock<std::mutex> lock(m_queue_mutex);

        m_cv.wait(lock, [this]() { return !m_query_queue.empty() || m_stop_thread; });

        if (!m_query_queue.empty()) {
            InfluxDBQuery* query = m_query_queue.dequeue();
            lock.unlock();

            executeQuery(query);
        }
    }

}
