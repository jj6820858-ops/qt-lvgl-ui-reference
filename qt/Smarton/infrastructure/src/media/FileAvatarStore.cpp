#include <smarton/infrastructure/media/FileAvatarStore.h>

#include <QtCore/QCryptographicHash>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QStandardPaths>
#include <QtCore/QUrl>
#include <QtGui/QImageReader>

#include <utility>

namespace smarton::infrastructure {

FileAvatarStore::FileAvatarStore()
    : m_directory(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                  + QStringLiteral("/avatars"))
{
}

FileAvatarStore::FileAvatarStore(QString directory)
    : m_directory(std::move(directory))
{
}

QString FileAvatarStore::safeStem(const QString &ownerId)
{
    // The owner id comes from a database row and is used to build a FILE NAME.
    // Hashing it means no value it could ever hold - a slash, "..", a null -
    // can steer where the file lands.
    return QString::fromLatin1(
        QCryptographicHash::hash(ownerId.toUtf8(), QCryptographicHash::Sha256)
            .toHex()
            .left(16));
}

bool FileAvatarStore::isUsable(const QString &path) const
{
    if (path.isEmpty())
        return false;
    const QFileInfo info(path);
    return info.exists() && info.isFile() && info.isReadable();
}

QString FileAvatarStore::store(const QString &sourceFile, const QString &ownerId)
{
    m_lastError.clear();

    // A file dialog returns a URL; a config file might hold a plain path.
    const QString localPath = sourceFile.startsWith(QLatin1String("file:"))
                                  ? QUrl(sourceFile).toLocalFile()
                                  : sourceFile;

    const QFileInfo source(localPath);
    if (!source.exists() || !source.isFile() || !source.isReadable()) {
        m_lastError = QStringLiteral("cannot read %1").arg(localPath);
        return {};
    }
    if (source.size() > kMaxBytes) {
        m_lastError = QStringLiteral("picture is larger than %1 MB")
                          .arg(kMaxBytes / (1024 * 1024));
        return {};
    }

    // Decided by CONTENT, not by extension: a .txt renamed to .png would
    // otherwise be copied in and then fail to render with no explanation.
    QImageReader reader(localPath);
    reader.setDecideFormatFromContent(true);
    if (!reader.canRead()) {
        m_lastError = QStringLiteral("%1 is not an image this build can read")
                          .arg(source.fileName());
        return {};
    }

    QDir dir(m_directory);
    if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
        m_lastError = QStringLiteral("cannot create %1").arg(m_directory);
        return {};
    }

    const QString suffix = QString::fromLatin1(reader.format()).toLower();
    const QString target = dir.filePath(
        QStringLiteral("%1.%2").arg(safeStem(ownerId),
                                    suffix.isEmpty() ? QStringLiteral("img") : suffix));

    // Remove any previous picture for this owner first, whatever its
    // extension: a switch from .png to .jpeg would otherwise leave the old
    // file behind forever.
    clear(ownerId);

    if (!QFile::copy(localPath, target)) {
        m_lastError = QStringLiteral("could not copy the picture into %1").arg(m_directory);
        return {};
    }
    return target;
}

void FileAvatarStore::clear(const QString &ownerId)
{
    QDir dir(m_directory);
    if (!dir.exists())
        return;

    const QString stem = safeStem(ownerId);
    const QFileInfoList existing =
        dir.entryInfoList({ stem + QStringLiteral(".*") }, QDir::Files);
    for (const QFileInfo &file : existing)
        QFile::remove(file.absoluteFilePath());
}

} // namespace smarton::infrastructure
