#include <smarton/models/DashboardViewModel.h>

#include <smarton/services/MonitoringService.h>

namespace smarton::models {

DashboardViewModel::DashboardViewModel(QObject *parent) : QObject(parent) { }

void DashboardViewModel::setService(services::MonitoringService *service)
{
    if (m_service == service)
        return;

    if (m_service)
        disconnect(m_service, nullptr, this, nullptr);

    m_service = service;
    if (!m_service)
        return;

    connect(m_service, &services::MonitoringService::readingsUpdated, this,
            [this](const QVector<domain::Reading> &readings) { m_readings.setReadings(readings); });

    connect(m_service, &services::MonitoringService::overallSeverityChanged, this,
            [this](common::Severity severity) {
                const int value = static_cast<int>(severity);
                if (value == m_overallSeverity)
                    return;
                m_overallSeverity = value;
                emit overallSeverityChanged();
            });

    m_readings.setReadings(m_service->readings());
}

void DashboardViewModel::setRunning(bool running)
{
    if (running == m_running)
        return;

    m_running = running;
    emit runningChanged();
    if (m_running)
        emit startRequested();
    else
        emit stopRequested();
}

} // namespace smarton::models
