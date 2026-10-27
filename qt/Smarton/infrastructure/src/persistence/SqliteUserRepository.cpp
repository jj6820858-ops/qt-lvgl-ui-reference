#include <smarton/infrastructure/persistence/SqliteUserRepository.h>

#include <QtCore/QDir>
#include <QtCore/QPair>
#include <QtCore/QFileInfo>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>
#include <QtSql/QSqlRecord>

#include <utility>

namespace smarton::infrastructure {

using domain::PasswordHash;
using domain::Role;
using domain::User;

SqliteUserRepository::SqliteUserRepository(QString connectionName)
    : m_connectionName(std::move(connectionName))
{
}

SqliteUserRepository::~SqliteUserRepository()
{
    close();
}

bool SqliteUserRepository::open(const QString &path)
{
    DatabaseConfig config;
    config.driver = QStringLiteral("QSQLITE");
    config.databaseName = path;
    return open(config);
}

bool SqliteUserRepository::open(const DatabaseConfig &config)
{
    close();
    m_config = config;

    if (!config.driverAvailable()) {
        // Named explicitly, because "driver not loaded" with no driver name is
        // one of the least useful errors Qt produces.
        m_lastError = QStringLiteral("the %1 driver is not available in this Qt build")
                          .arg(config.driver);
        return false;
    }

    // ":memory:" is how the tests run without touching disk.
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

    // SQLite-only tuning. WAL is what makes a power cut on the panel survivable;
    // a server has its own durability story and rejects these outright.
    if (config.isFileBased()) {
        QSqlQuery pragma(m_db);
        pragma.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
        pragma.exec(QStringLiteral("PRAGMA journal_mode = WAL"));
    }

    return applySchema();
}

QString SqliteUserRepository::primaryKeyClause() const
{
    // The only dialect difference in the entire schema. Everything else is
    // ordinary SQL with bound parameters, which is why swapping the driver is
    // a config change rather than a rewrite.
    if (m_config.driver == QLatin1String("QMYSQL"))
        return QStringLiteral("BIGINT PRIMARY KEY AUTO_INCREMENT");
    if (m_config.driver == QLatin1String("QPSQL"))
        return QStringLiteral("BIGSERIAL PRIMARY KEY");
    return QStringLiteral("INTEGER PRIMARY KEY AUTOINCREMENT");
}

void SqliteUserRepository::close()
{
    if (m_db.isOpen())
        m_db.close();
    m_db = QSqlDatabase();
    if (QSqlDatabase::contains(m_connectionName))
        QSqlDatabase::removeDatabase(m_connectionName);
}

bool SqliteUserRepository::applySchema()
{
    // Written to be portable rather than clever. Three things differ between
    // SQLite and a server, and all three are isolated here:
    //   - the auto-increment spelling (primaryKeyClause)
    //   - COLLATE NOCASE, which only SQLite has and only SQLite needs
    //   - the "now" function
    // Everything else is ordinary SQL with bound parameters, which is why
    // changing driver is a config change. See ADR-0012.
    const QString collate = m_config.isFileBased()
                                ? QStringLiteral(" COLLATE NOCASE") : QString();
    const QString now = m_config.driver == QLatin1String("QSQLITE")
                            ? QStringLiteral("(datetime('now'))")
                            : QStringLiteral("CURRENT_TIMESTAMP");

    QSqlQuery q(m_db);
    const bool ok = q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS users ("
        "  id               %1,"
        "  username         VARCHAR(190) NOT NULL UNIQUE%2,"
        "  password_hash    VARCHAR(255) NOT NULL,"
        "  role             VARCHAR(32)  NOT NULL DEFAULT 'viewer',"
        "  failed_attempts  INTEGER      NOT NULL DEFAULT 0,"
        "  locked_until     VARCHAR(64),"
        "  avatar_path      VARCHAR(512),"
        "  full_name        VARCHAR(190),"
        "  email            VARCHAR(190),"
        "  phone            VARCHAR(64),"
        "  created_at       VARCHAR(64)  NOT NULL DEFAULT %3)")
        .arg(primaryKeyClause(), collate, now));

    if (!ok) {
        m_lastError = q.lastError().text();
        return false;
    }
    return migrate();
}

bool SqliteUserRepository::migrate()
{
    // CREATE TABLE IF NOT EXISTS does nothing to a table that already exists,
    // so a column added after the first release has to be added explicitly.
    // Checking the record rather than catching an error keeps this quiet on
    // every start after the first, and works on SQLite and MySQL alike.
    const QSqlRecord existing = m_db.record(QStringLiteral("users"));
    if (existing.isEmpty())
        return true;

    // Column by column, each guarded by its own check. The previous version
    // tested ONE column and returned early if it was present, which meant the
    // second migration to be added would never run on a database that had
    // already taken the first.
    static const QList<QPair<QString, QString>> kColumns {
        { QStringLiteral("avatar_path"), QStringLiteral("VARCHAR(512)") },
        { QStringLiteral("full_name"),   QStringLiteral("VARCHAR(190)") },
        { QStringLiteral("email"),       QStringLiteral("VARCHAR(190)") },
        { QStringLiteral("phone"),       QStringLiteral("VARCHAR(64)")  },
    };

    for (const auto &[name, type] : kColumns) {
        if (existing.indexOf(name) >= 0)
            continue;

        QSqlQuery q(m_db);
        // The column NAME is from the literal list above, never from input -
        // this is the one place in the class that builds SQL by concatenation,
        // because ALTER TABLE cannot take a bound identifier.
        if (!q.exec(QStringLiteral("ALTER TABLE users ADD COLUMN %1 %2")
                        .arg(name, type))) {
            m_lastError = q.lastError().text();
            return false;
        }
    }
    return true;
}

std::optional<User> SqliteUserRepository::findByUsername(const QString &username)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT id, username, password_hash, role, failed_attempts, locked_until, "
        "       avatar_path, full_name, email, phone "
        "FROM users WHERE username = :username"));
    q.bindValue(QStringLiteral(":username"), username);

    if (!q.exec()) {
        m_lastError = q.lastError().text();
        return std::nullopt;
    }
    if (!q.next())
        return std::nullopt;

    return hydrate(q);
}

// One mapping for both lookups. Two copies of this drifted apart the moment a
// column was added, which is exactly how avatar_path came to be read in one
// query and not the other.
User SqliteUserRepository::hydrate(const QSqlQuery &q)
{
    User user(q.value(0).toLongLong(),
              q.value(1).toString(),
              domain::roleFromString(q.value(3).toString()),
              PasswordHash::fromStorage(q.value(2).toString()));

    user.setFailedAttempts(q.value(4).toInt());
    const QString locked = q.value(5).toString();
    if (!locked.isEmpty())
        user.setLockedUntil(QDateTime::fromString(locked, Qt::ISODate));
    user.setAvatarSource(q.value(6).toString());
    user.setFullName(q.value(7).toString());
    user.setEmail(q.value(8).toString());
    user.setPhone(q.value(9).toString());

    return user;
}

std::optional<User> SqliteUserRepository::findById(qint64 id)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT id, username, password_hash, role, failed_attempts, locked_until, "
        "       avatar_path, full_name, email, phone "
        "FROM users WHERE id = :id"));
    q.bindValue(QStringLiteral(":id"), id);

    if (!q.exec()) {
        m_lastError = q.lastError().text();
        return std::nullopt;
    }
    if (!q.next())
        return std::nullopt;

    return hydrate(q);
}

bool SqliteUserRepository::save(const User &user)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "UPDATE users SET password_hash = :hash, role = :role, "
        "failed_attempts = :attempts, locked_until = :locked, "
        "avatar_path = :avatar, full_name = :fullName, email = :email, "
        "phone = :phone WHERE id = :id"));
    q.bindValue(QStringLiteral(":hash"),     user.passwordHash().toStorage());
    q.bindValue(QStringLiteral(":role"),     domain::roleToString(user.role()));
    q.bindValue(QStringLiteral(":attempts"), user.failedAttempts());
    q.bindValue(QStringLiteral(":locked"),
                user.lockedUntil().isValid()
                    ? user.lockedUntil().toString(Qt::ISODate) : QString());
    q.bindValue(QStringLiteral(":avatar"),   user.avatarSource());
    q.bindValue(QStringLiteral(":fullName"), user.fullName());
    q.bindValue(QStringLiteral(":email"),    user.email());
    q.bindValue(QStringLiteral(":phone"),    user.phone());
    q.bindValue(QStringLiteral(":id"), user.id());

    if (!q.exec()) {
        m_lastError = q.lastError().text();
        return false;
    }
    return true;
}

bool SqliteUserRepository::isEmpty()
{
    QSqlQuery q(m_db);
    if (!q.exec(QStringLiteral("SELECT COUNT(*) FROM users")) || !q.next()) {
        m_lastError = q.lastError().text();
        return true;
    }
    return q.value(0).toInt() == 0;
}

qint64 SqliteUserRepository::createUser(const QString &username,
                                        const PasswordHash &hash, Role role)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT INTO users (username, password_hash, role) "
        "VALUES (:username, :hash, :role)"));
    q.bindValue(QStringLiteral(":username"), username);
    q.bindValue(QStringLiteral(":hash"),     hash.toStorage());
    q.bindValue(QStringLiteral(":role"),     domain::roleToString(role));

    if (!q.exec()) {
        // The UNIQUE constraint on username lands here. Reported as 0 rather
        // than distinguished, because "that name is taken" is the only failure
        // a caller can act on and the rest are storage problems.
        m_lastError = q.lastError().text();
        return 0;
    }
    return q.lastInsertId().toLongLong();
}

} // namespace smarton::infrastructure
