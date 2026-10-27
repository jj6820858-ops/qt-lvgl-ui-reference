#pragma once

#include <smarton/domain/entities/HomeEntities.h>

#include <QtCore/QJsonArray>
#include <QtCore/QList>
#include <QtCore/QObject>

namespace smarton::services {

/**
 * @brief Where the activity log is kept between runs.
 *
 * An array, not the home model's snapshot. A log is append-only and unbounded
 * where the model is a fixed shape that gets edited, and mixing them would
 * mean every device toggle rewriting the whole house - and a restored backup
 * carrying somebody else's history, which is the wrong answer to "what
 * happened here".
 */
class IActivityStore
{
public:
    virtual ~IActivityStore() = default;

    [[nodiscard]] virtual QJsonArray load() = 0;
    virtual bool save(const QJsonArray &entries) = 0;
};

/**
 * @brief What happened in the house, newest first.
 *
 * NOTHING BELOW THE COMPOSITION ROOT KNOWS THIS EXISTS. HomeService already
 * announces every change it makes and AuthService already announces every
 * sign-in; the root connects those signals to this. That is deliberate and it
 * is the whole design: a services layer where each service also writes to a
 * log has a log-shaped dependency running through every class in it, and the
 * first thing anyone wants to change - what gets logged - then means editing
 * all of them.
 *
 * It also means the log can name an actor. HomeService knows the signed-in
 * ROLE and AuthService knows the NAME; neither knows both, and the root knows
 * both because composing them is its job.
 *
 * BOUNDED, at \l kMaxEntries. This runs on a panel that is never switched off
 * and logs a line every time somebody walks past a light switch: unbounded,
 * the interesting question is not whether it fills the disk but when.
 */
class ActivityLog : public QObject
{
    Q_OBJECT
public:
    explicit ActivityLog(QObject *parent = nullptr);

    /*! Roughly a fortnight of a busy household, and about 40 KB. Old enough
        to answer "what happened while I was away", small enough to read and
        to write on every append without thinking about it. */
    static constexpr int kMaxEntries = 400;

    /** Attach the store. Optional: without one the log works and forgets. */
    void setStore(IActivityStore *store);
    /** Read whatever was stored. Safe to call with no store. */
    void load();

    /*! Record one thing. @p actor empty means the house did it to itself. */
    void record(const QString &kind, const QString &subject,
                const QString &detail, const QString &actor = {});

    /** Newest first, which is the order anybody reads a log in. */
    [[nodiscard]] const QList<domain::ActivityEntry> &entries() const { return m_entries; }
    [[nodiscard]] int count() const { return int(m_entries.size()); }

    /*! Forget everything. The one operation a log needs that a list does not:
        somebody selling the panel, or handing it to a tenant. */
    void clear();

signals:
    /** One entry was added, at the front. */
    void recorded();
    /** The whole list changed - loaded or cleared. */
    void reset();

private:
    void persist();

    IActivityStore *m_store = nullptr;
    QList<domain::ActivityEntry> m_entries;
};

} // namespace smarton::services
