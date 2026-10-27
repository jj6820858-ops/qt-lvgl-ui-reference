#include <smarton/infrastructure/persistence/SqliteHomeStore.h>

#include <QtCore/QJsonDocument>
#include <QtSql/QSqlDatabase>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>

#include <utility>

namespace smarton::infrastructure {

namespace {
// A fixed key, because there is exactly one model. A row per space arrives the
// day the product supports more than one, and the schema already allows it.
constexpr auto kModelKey = "home";
}

SqliteHomeStore::SqliteHomeStore(QString connectionName)
    : m_connectionName(std::move(connectionName))
{
}

bool SqliteHomeStore::prepare()
{
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen()) {
        m_lastError = QStringLiteral("connection '%1' is not open").arg(m_connectionName);
        return false;
    }

    const QString now = m_driver == QLatin1String("QSQLITE")
                            ? QStringLiteral("(datetime('now'))")
                            : QStringLiteral("CURRENT_TIMESTAMP");

    QSqlQuery q(db);
    const bool ok = q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS home_model ("
        "  key        VARCHAR(64) PRIMARY KEY,"
        "  document   TEXT NOT NULL,"
        "  updated_at VARCHAR(64) NOT NULL DEFAULT %1)").arg(now));
    if (!ok)
        m_lastError = q.lastError().text();
    return ok;
}

QJsonObject SqliteHomeStore::load()
{
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen())
        return {};

    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT document FROM home_model WHERE key = :key"));
    q.bindValue(QStringLiteral(":key"), QLatin1String(kModelKey));

    if (!q.exec() || !q.next())
        return {};

    QJsonParseError parseError {};
    const QJsonDocument doc =
        QJsonDocument::fromJson(q.value(0).toString().toUtf8(), &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        // A corrupt snapshot must not brick the app. Report it and return
        // nothing, so the caller falls back to the factory defaults.
        m_lastError = QStringLiteral("stored model is not valid JSON: %1")
                          .arg(parseError.errorString());
        return {};
    }
    return doc.object();
}

bool SqliteHomeStore::save(const QJsonObject &model)
{
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen()) {
        m_lastError = QStringLiteral("connection '%1' is not open").arg(m_connectionName);
        return false;
    }

    QSqlQuery q(db);
    // INSERT OR REPLACE is SQLite's; servers spell the same idea differently.
    // The alternative - DELETE then INSERT - works everywhere but is two round
    // trips on every device toggle.
    const QString upsert =
        m_driver == QLatin1String("QMYSQL")
            ? QStringLiteral("REPLACE INTO home_model (key, document, updated_at) "
                             "VALUES (:key, :document, CURRENT_TIMESTAMP)")
        : m_driver == QLatin1String("QPSQL")
            ? QStringLiteral("INSERT INTO home_model (key, document, updated_at) "
                             "VALUES (:key, :document, CURRENT_TIMESTAMP) "
                             "ON CONFLICT (key) DO UPDATE SET document = EXCLUDED.document, "
                             "updated_at = EXCLUDED.updated_at")
            : QStringLiteral("INSERT OR REPLACE INTO home_model (key, document, updated_at) "
                             "VALUES (:key, :document, datetime('now'))");
    q.prepare(upsert);
    q.bindValue(QStringLiteral(":key"), QLatin1String(kModelKey));
    // Compact, not indented: this is machine storage, and indentation would
    // roughly double what the panel's flash writes on every toggle.
    q.bindValue(QStringLiteral(":document"),
                QString::fromUtf8(QJsonDocument(model).toJson(QJsonDocument::Compact)));

    if (!q.exec()) {
        m_lastError = q.lastError().text();
        return false;
    }
    return true;
}

} // namespace smarton::infrastructure
