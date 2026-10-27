#pragma once

#include <smarton/services/IAvatarStore.h>

namespace smarton::infrastructure {

/**
 * @brief IAvatarStore backed by a directory under AppDataLocation.
 *
 * Validation matters more here than it looks. The input is a path a person
 * chose in a file dialog, which means it can be anything: a 40 MB RAW, a text
 * file renamed .png, or a path with a traversal sequence in it. All three are
 * rejected before anything is copied.
 */
class FileAvatarStore final : public services::IAvatarStore
{
public:
    /** Defaults to <AppDataLocation>/avatars. */
    FileAvatarStore();
    explicit FileAvatarStore(QString directory);

    static constexpr qint64 kMaxBytes = 8 * 1024 * 1024;

    [[nodiscard]] QString store(const QString &sourceFile,
                                const QString &ownerId) override;
    void clear(const QString &ownerId) override;
    [[nodiscard]] bool isUsable(const QString &path) const override;

    [[nodiscard]] QString directory() const { return m_directory; }
    [[nodiscard]] QString lastError() const { return m_lastError; }

private:
    /** ownerId reaches this from a database row; it must not steer the path. */
    [[nodiscard]] static QString safeStem(const QString &ownerId);

    QString m_directory;
    QString m_lastError;
};

} // namespace smarton::infrastructure
