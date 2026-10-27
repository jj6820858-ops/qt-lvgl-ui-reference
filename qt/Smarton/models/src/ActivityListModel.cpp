#include <smarton/models/ActivityListModel.h>

#include <smarton/services/ActivityLog.h>

#include <QtCore/QDateTime>
#include <QtCore/QLocale>

namespace smarton::models {

ActivityListModel::ActivityListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void ActivityListModel::setLog(services::ActivityLog *log)
{
    if (m_log == log)
        return;

    if (m_log)
        m_log->disconnect(this);

    m_log = log;
    if (m_log) {
        connect(m_log, &services::ActivityLog::recorded,
                this, &ActivityListModel::refresh);
        connect(m_log, &services::ActivityLog::reset,
                this, &ActivityListModel::refresh);
    }
    refresh();
}

void ActivityListModel::clear()
{
    if (m_log)
        m_log->clear();
}

void ActivityListModel::refresh()
{
    beginResetModel();
    endResetModel();
}

int ActivityListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() || !m_log ? 0 : m_log->count();
}

QVariant ActivityListModel::data(const QModelIndex &index, int role) const
{
    if (!m_log || !index.isValid() || index.row() < 0
        || index.row() >= m_log->count()) {
        return {};
    }

    const domain::ActivityEntry &entry = m_log->entries().at(index.row());
    switch (role) {
    case WhenRole:    return entry.when;
    case WhenTextRole: {
        // Relative where relative is useful and absolute where it is not.
        // "14:32" is only meaningful if you already know it was today, and
        // "31/08/2026 14:32" on every line of a log you are scanning is
        // eleven characters of noise per row.
        const QLocale locale;
        const QDate today = QDate::currentDate();
        const QDate day = entry.when.date();
        if (day == today)
            return ActivityListModel::tr("Today %1").arg(locale.toString(entry.when.time(), QLocale::ShortFormat));
        if (day == today.addDays(-1))
            return ActivityListModel::tr("Yesterday %1").arg(locale.toString(entry.when.time(), QLocale::ShortFormat));
        if (day > today.addDays(-7))
            return QStringLiteral("%1 %2").arg(locale.dayName(day.dayOfWeek(), QLocale::ShortFormat),
                                               locale.toString(entry.when.time(), QLocale::ShortFormat));
        return locale.toString(day, QLocale::ShortFormat);
    }
    case KindRole:     return entry.kind;
    case SubjectRole:  return entry.subject;
    case DetailRole:   return entry.detail;
    case ActorRole:    return entry.actor;
    case BySystemRole: return entry.actor.isEmpty();
    default:           return {};
    }
}

QHash<int, QByteArray> ActivityListModel::roleNames() const
{
    return {
        { WhenRole,      "when"      },
        { WhenTextRole,  "whenText"  },
        { KindRole,      "kind"      },
        { SubjectRole,   "subject"   },
        { DetailRole,    "detail"    },
        { ActorRole,     "actor"     },
        { BySystemRole,  "bySystem"  },
    };
}

} // namespace smarton::models
