#include <smarton/infrastructure/persistence/SqliteSessionRepository.h>

#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>

#include <utility>

namespace smarton::infrastructure {

using services::StoredSession;

namespace {
/** One place, so a change cannot be applied to the read and not the write. */
QString toStorage(const QDateTime &when)
{
    return when.isValid() ? when.toUTC().toString(Qt::ISODate) : QString();
}

QDateTime fromStorage(const QString &text)
{
    if (text.isEmpty())
        return {};
    QDateTime parsed = QDateTime::fromString(text, Qt::ISODate);
    // Written as UTC; a value read back without a timezone would otherwise be
    // interpreted as local time and shift every expiry by the UTC offset.
    parsed.setTimeSpec(Qt::UTC);
    return parsed;
}
} // namespace

SqliteSessionRepository::SqliteSessionRepository(QString connectionName)
    : m_connectionName(std::move(connectionName))
{
}

SqliteSessionRepository::~SqliteSessionRepository()
{
    close();
}

bool SqliteSessionRepository::open(const DatabaseConfig &config)
{
    close();
    m_config = config;

    if (!config.driverAvailable()) {
        m_lastError = QStringLiteral("the %1 driver is not available in this Qt build")
                          .arg(config.driver);
        return false;
    }

    if (config.isFileBased() && config.databaseName != QLatin1String(":memory:")) {
        const QDir dir = QFileInfo(config.databaseName).absoluteDir();
        if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
            m_lastError = QStringLiteral("cannot create %1").arg(dir.absolutePath());
            return false;
        }
    }

    m_db = QSqlDatabase::addDatabase(config.driver, m_connectionName);
    m_db.setDatabaseName(config.databaseName);
    if (!config.isFileBased()) {
        m_db.setHostName(config.hostName);
        if (config.port > 0)
            m_db.setPort(config.port);
        m_db.setUserName(config.userName);
        m_db.setPassword(config.password);
    }
    if (!config.connectOptions.isEmpty())
        m_db.setConnectOptions(config.connectOptions);

    if (!m_db.open()) {
        m_lastError = m_db.lastError().text();
        return false;
    }

    if (config.isFileBased()) {
        QSqlQuery pragma(m_db);
        pragma.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
        pragma.exec(QStringLiteral("PRAGMA journal_mode = WAL"));
    }

    return applySchema();
}

QString SqliteSessionRepository::primaryKeyClause() const
{
    if (m_config.driver == QLatin1String("QMYSQL"))
        return QStringLiteral("BIGINT PRIMARY KEY AUTO_INCREMENT");
    if (m_config.driver == QLatin1String("QPSQL"))
        return QStringLiteral("BIGSERIAL PRIMARY KEY");
    return QStringLiteral("INTEGER PRIMARY KEY AUTOINCREMENT");
}

void SqliteSessionRepository::close()
{
    if (m_db.isOpen())
        m_db.close();
    m_db = QSqlDatabase();
    if (QSqlDatabase::contains(m_connectionName))
        QSqlDatabase::removeDatabase(m_connectionName);
}

bool SqliteSessionRepository::applySchema()
{
    QSqlQuery q(m_db);

    // No FOREIGN KEY to users(id), deliberately: this table is created by a
    // second connection that does not own the users table's lifetime, and a
    // cross-connection constraint would make the open order significant.
    // removeAllForUser() at sign-out is what keeps the rows honest.
    if (!q.exec(QStringLiteral(
            "CREATE TABLE IF NOT EXISTS sessions ("
            "  id           %1,"
            "  user_id      BIGINT       NOT NULL,"
            "  selector     VARCHAR(64)  NOT NULL UNIQUE,"
            "  secret_hash  VARCHAR(128) NOT NULL,"
            "  issued_at    VARCHAR(64)  NOT NULL,"
            "  expires_at   VARCHAR(64)  NOT NULL,"
            "  last_used_at VARCHAR(64))")
            .arg(primaryKeyClause()))) {
        m_lastError = q.lastError().text();
        return false;
    }

    // Every lookup is by selector, and every sign-out is by user.
    q.exec(QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions (user_id)"));
    return true;
}

std::optional<StoredSession>
SqliteSessionRepository::findBySelector(const QString &selector)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT id, user_id, selector, secret_hash, issued_at, expires_at, "
        "       last_used_at FROM sessions WHERE selector = :selector"));
    q.bindValue(QStringLiteral(":selector"), selector);

    if (!q.exec()) {
        m_lastError = q.lastError().text();
        return std::nullopt;
    }
    if (!q.next())
        return std::nullopt;

    StoredSession session;
    session.id         = q.value(0).toLongLong();
    session.userId     = q.value(1).toLongLong();
    session.selector   = q.value(2).toString();
    session.secretHash = q.value(3).toString();
    session.issuedAt   = fromStorage(q.value(4).toString());
    session.expiresAt  = fromStorage(q.value(5).toString());
    session.lastUsedAt = fromStorage(q.value(6).toString());
    return session;
}

qint64 SqliteSessionRepository::insert(const StoredSession &session)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT INTO sessions (user_id, selector, secret_hash, issued_at, "
        "                      expires_at, last_used_at) "
        "VALUES (:user, :selector, :hash, :issued, :expires, :used)"));
    q.bindValue(QStringLiteral(":user"),     session.userId);
    q.bindValue(QStringLiteral(":selector"), session.selector);
    q.bindValue(QStringLiteral(":hash"),     session.secretHash);
    q.bindValue(QStringLiteral(":issued"),   toStorage(session.issuedAt));
    q.bindValue(QStringLiteral(":expires"),  toStorage(session.expiresAt));
    q.bindValue(QStringLiteral(":used"),     toStorage(session.lastUsedAt));

    if (!q.exec()) {
        m_lastError = q.lastError().text();
        return 0;
    }
    return q.lastInsertId().toLongLong();
}

bool SqliteSessionRepository::rotate(qint64 id, const QString &secretHash,
                                     const QDateTime &expiresAt,
                                     const QDateTime &lastUsedAt)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "UPDATE sessions SET secret_hash = :hash, expires_at = :expires, "
        "last_used_at = :used WHERE id = :id"));
    q.bindValue(QStringLiteral(":hash"),    secretHash);
    q.bindValue(QStringLiteral(":expires"), toStorage(expiresAt));
    q.bindValue(QStringLiteral(":used"),    toStorage(lastUsedAt));
    q.bindValue(QStringLiteral(":id"),      id);

    if (!q.exec()) {
        m_lastError = q.lastError().text();
        return false;
    }
    return q.numRowsAffected() != 0;
}

bool SqliteSessionRepository::remove(qint64 id)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM sessions WHERE id = :id"));
    q.bindValue(QStringLiteral(":id"), id);
    if (!q.exec()) {
        m_lastError = q.lastError().text();
        return false;
    }
    return true;
}

bool SqliteSessionRepository::removeAllForUser(qint64 userId)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM sessions WHERE user_id = :user"));
    q.bindValue(QStringLiteral(":user"), userId);
    if (!q.exec()) {
        m_lastError = q.lastError().text();
        return false;
    }
    return true;
}

int SqliteSessionRepository::purgeExpired(const QDateTime &now)
{
    QSqlQuery q(m_db);
    // String comparison, which is only sound because every value written here
    // goes through toStorage(): ISO-8601 in UTC sorts lexicographically in the
    // same order it sorts chronologically. Mixing in a local-time value would
    // quietly break that, which is why nothing else writes this column.
    q.prepare(QStringLiteral("DELETE FROM sessions WHERE expires_at <= :now"));
    q.bindValue(QStringLiteral(":now"), toStorage(now));
    if (!q.exec()) {
        m_lastError = q.lastError().text();
        return 0;
    }
    return q.numRowsAffected();
}

} // namespace smarton::infrastructure
