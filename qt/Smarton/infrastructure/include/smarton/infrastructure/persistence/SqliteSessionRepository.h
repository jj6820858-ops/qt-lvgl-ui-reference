#pragma once

#include <smarton/infrastructure/persistence/DatabaseConfig.h>
#include <smarton/services/ISessionRepository.h>

#include <QtSql/QSqlDatabase>

namespace smarton::infrastructure {

/**
 * @brief Remembered sign-ins, in the same database as the accounts.
 *
 * ITS OWN CONNECTION, NOT THE ACCOUNT REPOSITORY'S. Two reasons, and the
 * second is the one that matters. The first is ordinary separation - this
 * class owns one table and nothing else. The second is that a QSqlDatabase
 * belongs to the thread that opened it, and sharing one handle between two
 * objects makes "which thread may call this" a property of the pair rather
 * than of each class. Two connections to one SQLite file are ordinary under
 * WAL, which the account repository already enables.
 *
 * @note Prepared statements with bound values throughout, like every other
 *       repository here. No string concatenation into SQL.
 */
class SqliteSessionRepository final : public services::ISessionRepository
{
public:
    explicit SqliteSessionRepository(
        QString connectionName = QStringLiteral("smarton-sessions"));
    ~SqliteSessionRepository() override;

    [[nodiscard]] bool open(const DatabaseConfig &config);
    void close();

    [[nodiscard]] bool isOpen() const { return m_db.isOpen(); }
    [[nodiscard]] QString lastError() const { return m_lastError; }

    [[nodiscard]] std::optional<services::StoredSession>
        findBySelector(const QString &selector) override;
    qint64 insert(const services::StoredSession &session) override;
    bool rotate(qint64 id, const QString &secretHash,
                const QDateTime &expiresAt, const QDateTime &lastUsedAt) override;
    bool remove(qint64 id) override;
    bool removeAllForUser(qint64 userId) override;
    int purgeExpired(const QDateTime &now) override;

private:
    [[nodiscard]] bool applySchema();
    [[nodiscard]] QString primaryKeyClause() const;

    DatabaseConfig m_config;
    QSqlDatabase   m_db;
    QString        m_connectionName;
    QString        m_lastError;
};

} // namespace smarton::infrastructure
