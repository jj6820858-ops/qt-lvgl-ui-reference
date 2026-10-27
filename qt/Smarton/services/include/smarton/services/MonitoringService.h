#pragma once

#include <smarton/common/Severity.h>
#include <smarton/domain/entities/Reading.h>

#include <QtCore/QObject>
#include <QtCore/QVector>

namespace smarton::services {

class IReadingSource;

/**
 * @brief Watches a reading source and derives system-wide state from it.
 *
 * The only place that decides what "the system is in a critical state" means.
 * Putting that in the model or the UI would scatter a business rule across
 * layers that should not own it.
 */
class MonitoringService : public QObject
{
    Q_OBJECT
public:
    explicit MonitoringService(QObject *parent = nullptr);

    void setSource(IReadingSource *source);

    [[nodiscard]] QVector<domain::Reading> readings() const { return m_readings; }
    [[nodiscard]] common::Severity overallSeverity() const { return m_overall; }

signals:
    void readingsUpdated(const QVector<smarton::domain::Reading> &readings);
    void overallSeverityChanged(smarton::common::Severity severity);

private:
    void onReadings(const QVector<domain::Reading> &readings);

    QVector<domain::Reading> m_readings;
    IReadingSource *m_source = nullptr;
    common::Severity m_overall = common::Severity::Normal;
};

} // namespace smarton::services
