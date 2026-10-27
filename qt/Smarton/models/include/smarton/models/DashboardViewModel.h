#pragma once

#include <smarton/models/ReadingListModel.h>

#include <QtCore/QObject>
#include <QtQml/qqmlregistration.h>

namespace smarton::services {
class MonitoringService;
}

namespace smarton::models {

/**
 * @brief Everything the dashboard screen binds to, and nothing else.
 *
 * One view model per screen. The screen never reaches past this object into
 * services or domain types — that is what keeps the QML testable against a
 * stub view model.
 */
class DashboardViewModel : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QAbstractListModel *readings READ readings CONSTANT)
    Q_PROPERTY(int overallSeverity READ overallSeverity NOTIFY overallSeverityChanged)
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)

public:
    explicit DashboardViewModel(QObject *parent = nullptr);

    [[nodiscard]] QAbstractListModel *readings() { return &m_readings; }
    [[nodiscard]] int overallSeverity() const { return m_overallSeverity; }
    [[nodiscard]] bool isRunning() const { return m_running; }

    void setService(services::MonitoringService *service);

    Q_INVOKABLE void setRunning(bool running);

signals:
    void overallSeverityChanged();
    void runningChanged();
    void startRequested();
    void stopRequested();

private:
    ReadingListModel m_readings;
    services::MonitoringService *m_service = nullptr;
    int m_overallSeverity = 0;
    bool m_running = false;
};

} // namespace smarton::models
