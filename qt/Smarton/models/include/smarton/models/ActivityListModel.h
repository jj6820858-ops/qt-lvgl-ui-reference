#pragma once

#include <smarton/domain/entities/HomeEntities.h>

#include <QtCore/QAbstractListModel>
#include <QtQml/qqmlregistration.h>

namespace smarton::services { class ActivityLog; }

namespace smarton::models {

/**
 * @brief The activity log, for QML. Newest first.
 *
 * RESETS RATHER THAN INSERTS, which is the opposite of what ADR-0003 asks
 * for everywhere else - and the exception is worth stating. A log only ever
 * grows at the front and drops off the back, so an incremental update is one
 * insert plus one remove; the reason this does not do that is that the list
 * is a scrolled page nobody is looking at while the house changes underneath
 * it, and a reset of 400 rows on a light switch costs a delegate rebuild for
 * however many rows are actually on screen - about eight.
 *
 * If that ever stops being true - a live "what is happening now" ticker on
 * the dashboard, say - this is the class that has to grow beginInsertRows.
 */
class ActivityListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

public:
    enum Roles {
        WhenRole = Qt::UserRole + 1,
        /*! Already formatted: "today, 14:32" / "Tue 09:15" / "12 Aug". A
            date is formatted against the user's locale and their idea of
            today, and neither belongs in QML string arithmetic. */
        WhenTextRole,
        KindRole,
        SubjectRole,
        DetailRole,
        ActorRole,
        /*! True when the house did it to itself - the schedule, the
            transport - rather than a person. The list draws those
            differently, because "who did this" is the question a log
            exists to answer. */
        BySystemRole,
    };
    Q_ENUM(Roles)

    explicit ActivityListModel(QObject *parent = nullptr);

    void setLog(services::ActivityLog *log);

    /*! Forget everything. Q_INVOKABLE because the only caller is a confirm
        dialog in QML, and routing it through the home view model would mean
        that class holding a pointer to a log it has nothing else to do
        with. */
    Q_INVOKABLE void clear();

    [[nodiscard]] int rowCount(const QModelIndex &parent = {}) const override;
    [[nodiscard]] QVariant data(const QModelIndex &index, int role) const override;
    [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

private:
    void refresh();

    services::ActivityLog *m_log = nullptr;
};

} // namespace smarton::models
