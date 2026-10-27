#pragma once

#include <smarton/services/ActivityLog.h>

#include <QtCore/QString>

namespace smarton::infrastructure {

/**
 * @brief The activity log, as one JSON file in application data.
 *
 * A FILE, not the database. The log is append-only, bounded and read only by
 * this application: it has no relations, nothing joins to it, and nothing
 * queries it by anything but "the most recent N", which is the shape a file
 * already is. Putting it in SQLite would buy indexes nobody needs and cost a
 * table, a migration and a second thing that can be out of step with the
 * schema.
 *
 * It is also deliberately NOT in the home model's snapshot, which is what
 * backup and restore carry: restoring a backup onto a panel should not
 * replace the record of what happened on that panel.
 *
 * Written whole on every append. At 400 entries that is about 40 KB, which is
 * one flash write per light switch on a device that is idle most of the time
 * - measurably cheaper than the machinery required to append safely to a
 * JSON array in place.
 */
class FileActivityStore final : public services::IActivityStore
{
public:
    FileActivityStore();
    /*! An explicit path, for tests. The default is
        AppDataLocation/activity.json. */
    explicit FileActivityStore(const QString &filePath);

    [[nodiscard]] QString fileName() const { return m_path; }
    [[nodiscard]] QString lastError() const { return m_lastError; }

    QJsonArray load() override;
    bool save(const QJsonArray &entries) override;

private:
    QString m_path;
    QString m_lastError;
};

} // namespace smarton::infrastructure
