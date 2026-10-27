#pragma once

#include <QtCore/QString>
#include <QtSql/QSqlDatabase>

namespace smarton::infrastructure {

/**
 * @brief Which database the app opens, and how.
 *
 * WHY THIS IS CONFIGURABLE, AND WHY THE DEFAULT IS SQLITE.
 *
 * SQLite is the right store for the panel and is the default: it is a file,
 * it needs no server, it survives a power cut with WAL, and it adds nothing to
 * a 1 GB Yocto image. A panel that cannot reach a MySQL server is a panel that
 * cannot turn on a light, which is not a trade anyone should make for a
 * hallway appliance.
 *
 * MySQL/MariaDB is supported anyway, because a multi-panel household or a
 * dashboard on a workstation wants one shared home model rather than one per
 * device. Qt's QSqlDatabase already abstracts the driver, so what was missing
 * was only that the driver name and connection parameters were hard-coded.
 *
 * Everything above this struct is driver-agnostic ALREADY: every statement in
 * the repositories is a prepared statement with bound values, and the only
 * dialect-specific SQL was `INSERT OR REPLACE`, which is now chosen per driver.
 * See docs/adr/0012-pluggable-sql-driver.md.
 */
struct DatabaseConfig
{
    /** QSQLITE (default), QMYSQL, QPSQL - any driver Qt was built with. */
    QString driver = QStringLiteral("QSQLITE");
    /** File path for SQLite; schema name for a server. */
    QString databaseName;
    QString hostName;
    int     port = 0;
    QString userName;
    QString password;
    /** Extra driver options, e.g. "MYSQL_OPT_RECONNECT=1". */
    QString connectOptions;

    [[nodiscard]] bool isFileBased() const
    {
        return driver == QLatin1String("QSQLITE") || driver == QLatin1String("QSQLITE3");
    }

    /**
     * Parse a URL: `sqlite:/path/to.db` or
     * `mysql://user:pass@host:3306/smarton`.
     *
     * A URL rather than six flags because it is one thing to put in a config
     * file, one thing to pass in an environment variable, and one thing to get
     * wrong. Returns a SQLite config pointed at @p fallbackPath when @p url is
     * empty.
     */
    [[nodiscard]] static DatabaseConfig fromUrl(const QString &url,
                                                const QString &fallbackPath);

    /** True when this driver is actually available in this Qt build. */
    [[nodiscard]] bool driverAvailable() const
    {
        return QSqlDatabase::isDriverAvailable(driver);
    }

    /** For logs. Never includes the password. */
    [[nodiscard]] QString describe() const;
};

} // namespace smarton::infrastructure
