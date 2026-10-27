#include <smarton/models/ReadingListModel.h>

namespace smarton::models {

ReadingListModel::ReadingListModel(QObject *parent) : QAbstractListModel(parent) { }

int ReadingListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : static_cast<int>(m_readings.size());
}

QVariant ReadingListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_readings.size())
        return {};

    const domain::Reading &r = m_readings.at(index.row());
    switch (role) {
    case LabelRole:
        return r.label();
    case UnitRole:
        return r.unit();
    case ValueRole:
        return r.value();
    case MinimumRole:
        return r.range().minimum;
    case MaximumRole:
        return r.range().maximum;
    case ProgressRole:
        return r.progress();
    case SeverityRole:
        return static_cast<int>(r.severity());
    default:
        return {};
    }
}

QHash<int, QByteArray> ReadingListModel::roleNames() const
{
    return {
        { LabelRole, QByteArrayLiteral("label") },
        { UnitRole, QByteArrayLiteral("unit") },
        { ValueRole, QByteArrayLiteral("value") },
        { MinimumRole, QByteArrayLiteral("minimum") },
        { MaximumRole, QByteArrayLiteral("maximum") },
        { ProgressRole, QByteArrayLiteral("progress") },
        { SeverityRole, QByteArrayLiteral("severity") },
    };
}

void ReadingListModel::setReadings(const QVector<domain::Reading> &readings)
{
    // Structural change: only here do we disturb delegate lifetimes.
    if (readings.size() != m_readings.size()) {
        beginResetModel();
        m_readings = readings;
        endResetModel();
        return;
    }

    // Same shape: touch only the rows that actually differ.
    int first = -1;
    int last = -1;
    for (int i = 0; i < readings.size(); ++i) {
        if (m_readings.at(i) != readings.at(i)) {
            m_readings[i] = readings.at(i);
            if (first < 0)
                first = i;
            last = i;
        }
    }

    if (first < 0)
        return; // nothing changed — emit nothing at all

    emit dataChanged(index(first), index(last), { ValueRole, ProgressRole, SeverityRole });
}

} // namespace smarton::models
