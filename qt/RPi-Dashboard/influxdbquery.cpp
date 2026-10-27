#include <influxdbconnection.h>

InfluxDBQuery::InfluxDBQuery(InfluxDBConnection *connection) : QObject{connection}, m_connection{connection}
{

}

void InfluxDBQuery::setQuery(const QString query)
{
    m_query = query;
}

void InfluxDBQuery::queueQuery()
{
    m_connection->queueQuery(this);
}

QString InfluxDBQuery::getQuery()
{
    return m_query;
}

void InfluxDBQuery::setQueryResult(QVariantList result)
{
    m_result = result;
    emit queryFinished(result);
}
