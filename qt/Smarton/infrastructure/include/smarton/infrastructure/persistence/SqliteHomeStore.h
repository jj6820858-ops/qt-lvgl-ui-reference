#pragma once

#include <smarton/services/HomeService.h>

#include <QtCore/QString>

namespace smarton::infrastructure {

/**
 * @brief The home model, stored as one JSON snapshot in SQLite.
 *
 * One row, one column. That is not laziness: the model is a small object graph
 * that is always read whole and written whole, and normalising it into five
 * tables would buy nothing but joins and five migrations every time an entity
 * gains a field. When a query like "every device across all spaces" appears,
 * that is the moment to normalise - not before.
 *
 * Shares the connection opened by SqliteUserRepository: one database file, one
 * connection, one thread. Do not call this from a worker thread.
 */
class SqliteHomeStore final : public services::IHomeStore
{
public:
    explicit SqliteHomeStore(QString connectionName = QStringLiteral("smarton"));

    /** Tell the store which dialect it is talking, for the one statement that
        differs. Defaults to SQLite. */
    void setDriver(const QString &driver) { m_driver = driver; }

    /** Create the table. Safe to call on every start. */
    [[nodiscard]] bool prepare();
    [[nodiscard]] QString lastError() const { return m_lastError; }

    [[nodiscard]] QJsonObject load() override;
    bool save(const QJsonObject &model) override;

private:
    QString m_connectionName;
    QString m_driver = QStringLiteral("QSQLITE");
    QString m_lastError;
};

} // namespace smarton::infrastructure
