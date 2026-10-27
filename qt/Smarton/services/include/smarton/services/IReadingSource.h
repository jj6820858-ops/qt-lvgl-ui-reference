#pragma once

#include <smarton/domain/entities/Reading.h>

#include <QtCore/QObject>
#include <QtCore/QVector>

namespace smarton::services {

/**
 * @brief Anything that can produce readings.
 *
 * Declared here, in the service layer, and implemented in `infrastructure`.
 * This is the inversion that lets the whole application be tested with a fake
 * source and no hardware: services depend on the interface, never on the
 * concrete transport.
 */
class IReadingSource : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    ~IReadingSource() override = default;

    [[nodiscard]] virtual QVector<domain::Reading> snapshot() const = 0;

    virtual void start() = 0;
    virtual void stop() = 0;

signals:
    void readingsChanged(const QVector<smarton::domain::Reading> &readings);
};

} // namespace smarton::services
