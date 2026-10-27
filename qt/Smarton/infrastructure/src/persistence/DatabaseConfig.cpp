#include <smarton/infrastructure/persistence/DatabaseConfig.h>

#include <QtCore/QUrl>

namespace smarton::infrastructure {

DatabaseConfig DatabaseConfig::fromUrl(const QString &url, const QString &fallbackPath)
{
    DatabaseConfig config;

    if (url.isEmpty()) {
        config.driver = QStringLiteral("QSQLITE");
        config.databaseName = fallbackPath;
        return config;
    }

    // A bare path is treated as SQLite, so `--database /tmp/x.db` keeps working
    // and nobody has to learn a URL scheme to point at a scratch file.
    if (!url.contains(QLatin1String("://")) && !url.startsWith(QLatin1String("sqlite:"))) {
        config.driver = QStringLiteral("QSQLITE");
        config.databaseName = url;
        return config;
    }

    if (url.startsWith(QLatin1String("sqlite:"))) {
        config.driver = QStringLiteral("QSQLITE");
        config.databaseName = url.mid(QStringLiteral("sqlite:").size());
        // sqlite:///path and sqlite:/path both mean the same thing to a person.
        while (config.databaseName.startsWith(QLatin1String("//")))
            config.databaseName = config.databaseName.mid(1);
        return config;
    }

    const QUrl parsed(url);
    const QString scheme = parsed.scheme().toLower();
    if (scheme == QLatin1String("mysql") || scheme == QLatin1String("mariadb"))
        config.driver = QStringLiteral("QMYSQL");
    else if (scheme == QLatin1String("postgres") || scheme == QLatin1String("postgresql"))
        config.driver = QStringLiteral("QPSQL");
    else
        config.driver = scheme.toUpper();

    config.hostName = parsed.host();
    config.port = parsed.port(0);
    config.userName = parsed.userName();
    config.password = parsed.password();
    config.databaseName = parsed.path().mid(1);      // strip the leading '/'
    config.connectOptions = parsed.query();
    return config;
}

QString DatabaseConfig::describe() const
{
    if (isFileBased())
        return QStringLiteral("%1 at %2").arg(driver, databaseName);

    // Password deliberately omitted: this string goes to a log, and a log is
    // the most common place a credential ends up by accident.
    return QStringLiteral("%1 %2@%3:%4/%5")
        .arg(driver, userName.isEmpty() ? QStringLiteral("(no user)") : userName,
             hostName, QString::number(port), databaseName);
}

} // namespace smarton::infrastructure
