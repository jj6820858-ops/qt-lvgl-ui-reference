#pragma once

#include <smarton/domain/entities/Reading.h>

#include <QtCore/QAbstractListModel>
#include <QtQml/qqmlregistration.h>

namespace smarton::models {

/**
 * @brief Exposes domain readings to QML as roles.
 *
 * @note Updates are incremental. A full model reset destroys and recreates
 *       every delegate — see docs/adr/0003-incremental-model-updates.md.
 */
class ReadingListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

public:
    enum Roles {
        LabelRole = Qt::UserRole + 1,
        UnitRole,
        ValueRole,
        MinimumRole,
        MaximumRole,
        ProgressRole,
        SeverityRole,
    };
    Q_ENUM(Roles)

    explicit ReadingListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    /** C++-side entry point. Not Q_INVOKABLE: QML does not push data in. */
    void setReadings(const QVector<domain::Reading> &readings);

private:
    QVector<domain::Reading> m_readings;
};

} // namespace smarton::models
