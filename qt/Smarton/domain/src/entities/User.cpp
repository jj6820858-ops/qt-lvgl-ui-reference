#include <smarton/domain/entities/User.h>

#include <utility>

namespace smarton::domain {

QString roleToString(Role role)
{
    switch (role) {
    case Role::Owner:         return QStringLiteral("owner");
    case Role::Administrator: return QStringLiteral("administrator");
    case Role::Installer:     return QStringLiteral("installer");
    case Role::Operator:      return QStringLiteral("operator");
    case Role::Guest:         return QStringLiteral("guest");
    case Role::Viewer:        break;
    }
    return QStringLiteral("viewer");
}

Role roleFromString(const QString &text)
{
    if (text == QLatin1String("owner"))
        return Role::Owner;
    if (text == QLatin1String("administrator"))
        return Role::Administrator;
    if (text == QLatin1String("installer"))
        return Role::Installer;
    if (text == QLatin1String("operator"))
        return Role::Operator;
    if (text == QLatin1String("guest"))
        return Role::Guest;
    return Role::Viewer;
}

User::User(qint64 id, QString username, Role role, PasswordHash hash)
    : m_id(id)
    , m_username(std::move(username))
    , m_role(role)
    , m_hash(std::move(hash))
{
}

bool User::isLocked(const QDateTime &now) const
{
    return m_lockedUntil.isValid() && m_lockedUntil > now;
}

} // namespace smarton::domain
