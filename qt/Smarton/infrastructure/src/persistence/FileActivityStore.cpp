#include <smarton/infrastructure/persistence/FileActivityStore.h>

#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonParseError>
#include <QtCore/QSaveFile>
#include <QtCore/QStandardPaths>

namespace smarton::infrastructure {

FileActivityStore::FileActivityStore()
    : FileActivityStore(QStandardPaths::writableLocation(
                            QStandardPaths::AppDataLocation)
                        + QStringLiteral("/activity.json"))
{
}

FileActivityStore::FileActivityStore(const QString &filePath)
    : m_path(filePath)
{
    QDir().mkpath(QFileInfo(m_path).absolutePath());
}

QJsonArray FileActivityStore::load()
{
    QFile file(m_path);
    if (!file.open(QIODevice::ReadOnly)) {
        // Not an error worth reporting: the first run has no log yet, and a
        // panel that complains about its own empty history on every boot
        // teaches people to ignore what it says.
        return {};
    }

    QJsonParseError parse {};
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parse);
    file.close();

    if (parse.error != QJsonParseError::NoError || !doc.isArray()) {
        m_lastError = QStringLiteral("%1 is not a readable log").arg(m_path);
        return {};
    }
    m_lastError.clear();
    return doc.array();
}

bool FileActivityStore::save(const QJsonArray &entries)
{
    // QSaveFile, not QFile. This is written on every light switch on a device
    // whose power can be cut at any moment, and a half-written JSON array is
    // a log that will not load again - losing the whole history to save the
    // last line of it.
    QSaveFile file(m_path);
    if (!file.open(QIODevice::WriteOnly)) {
        m_lastError = QStringLiteral("cannot write %1").arg(m_path);
        return false;
    }

    file.write(QJsonDocument(entries).toJson(QJsonDocument::Compact));
    if (!file.commit()) {
        m_lastError = QStringLiteral("could not commit %1").arg(m_path);
        return false;
    }
    m_lastError.clear();
    return true;
}

} // namespace smarton::infrastructure
