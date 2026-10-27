#include <smarton/services/ActivityLog.h>

#include <QtCore/QJsonObject>

#include <utility>

namespace smarton::services {

using namespace smarton::domain;

namespace {

QString str(const QJsonObject &o, const char *key)
{
    return o.value(QLatin1String(key)).toString();
}

} // namespace

ActivityLog::ActivityLog(QObject *parent)
    : QObject(parent)
{
}

void ActivityLog::setStore(IActivityStore *store)
{
    m_store = store;
}

void ActivityLog::load()
{
    if (!m_store)
        return;

    m_entries.clear();
    const QJsonArray stored = m_store->load();
    m_entries.reserve(stored.size());
    for (const QJsonValue &value : stored) {
        const QJsonObject o = value.toObject();
        ActivityEntry entry;
        entry.when = QDateTime::fromString(str(o, "when"), Qt::ISODate);
        // A line with no readable time is a line nobody can place. Dropped
        // rather than shown at the epoch, which would sort it to the bottom
        // and read as something that happened in 1970.
        if (!entry.when.isValid())
            continue;
        entry.kind = str(o, "kind");
        entry.subject = str(o, "subject");
        entry.detail = str(o, "detail");
        entry.actor = str(o, "actor");
        m_entries.append(entry);
    }

    // Trimmed on the way in as well as on the way out: a hand-edited or
    // older file can be longer than this build's limit.
    while (m_entries.size() > kMaxEntries)
        m_entries.removeLast();

    emit reset();
}

void ActivityLog::record(const QString &kind, const QString &subject,
                         const QString &detail, const QString &actor)
{
    ActivityEntry entry;
    entry.when = QDateTime::currentDateTime();
    entry.kind = kind;
    entry.subject = subject;
    entry.detail = detail;
    entry.actor = actor;

    m_entries.prepend(entry);
    while (m_entries.size() > kMaxEntries)
        m_entries.removeLast();

    persist();
    emit recorded();
}

void ActivityLog::clear()
{
    if (m_entries.isEmpty())
        return;

    m_entries.clear();
    persist();
    emit reset();
}

void ActivityLog::persist()
{
    if (!m_store)
        return;

    QJsonArray array;
    for (const ActivityEntry &entry : std::as_const(m_entries)) {
        array.append(QJsonObject {
            { QStringLiteral("when"),    entry.when.toString(Qt::ISODate) },
            { QStringLiteral("kind"),    entry.kind },
            { QStringLiteral("subject"), entry.subject },
            { QStringLiteral("detail"),  entry.detail },
            { QStringLiteral("actor"),   entry.actor },
        });
    }
    (void)m_store->save(array);
}

} // namespace smarton::services
