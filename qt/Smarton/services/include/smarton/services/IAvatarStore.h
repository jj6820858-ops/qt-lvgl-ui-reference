#pragma once

#include <QtCore/QString>

namespace smarton::services {

/**
 * @brief Takes custody of a picture the user chose.
 *
 * WHY CUSTODY RATHER THAN A PATH. A file dialog hands back wherever the user
 * happened to browse to - a USB stick, a network mount, a Downloads folder
 * they will empty next week. Storing that path means the avatar works until it
 * does not, and then shows a broken image with no explanation.
 *
 * So the file is COPIED into application data and the copy's path is what gets
 * stored. On the panel that is also the only location guaranteed to be
 * writable and to survive a reboot.
 */
class IAvatarStore
{
public:
    virtual ~IAvatarStore() = default;

    /**
     * Copy @p sourceFile into managed storage for @p ownerId.
     * @return the stored absolute path, or an empty string on failure.
     */
    [[nodiscard]] virtual QString store(const QString &sourceFile,
                                        const QString &ownerId) = 0;

    /** Forget @p ownerId's picture, so the default is used again. */
    virtual void clear(const QString &ownerId) = 0;

    /** True when @p path exists and is readable. */
    [[nodiscard]] virtual bool isUsable(const QString &path) const = 0;
};

} // namespace smarton::services
