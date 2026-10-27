#ifndef INFLUXDBDATA_H
#define INFLUXDBDATA_H

#include <QDateTime>
//#include <QMetaType>

class InfluxDBData
{
    Q_GADGET

    Q_PROPERTY(QDateTime timestamp MEMBER m_timestamp)
    Q_PROPERTY(double data MEMBER m_data)

public:
    InfluxDBData() = default;
    ~InfluxDBData() = default;
    InfluxDBData(const InfluxDBData &) = default;
    InfluxDBData &operator=(const InfluxDBData &) = default;

    InfluxDBData(const QDateTime &timestamp, const double &data);

    double data() const;
    void setData(const double);

    QDateTime timestamp() const;
    void setTimestamp(const QDateTime &);

private:
    double m_data;
    QDateTime m_timestamp;
};

Q_DECLARE_METATYPE(InfluxDBData)

#endif // INFLUXDBDATA_H
