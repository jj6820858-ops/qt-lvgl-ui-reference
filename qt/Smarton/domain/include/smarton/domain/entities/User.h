#pragma once

#include <smarton/domain/valueobjects/PasswordHash.h>

#include <QtCore/QDateTime>
#include <QtCore/QString>

#include <utility>

namespace smarton::domain {

/** What a signed-in user is allowed to do. */
// Roles intentionally describe real people who use a wall panel.  Keep the
// values independent of their order: accounts are persisted as the strings
// returned by roleToString(), never as enum integers.
enum class Role { Viewer, Guest, Operator, Installer, Administrator, Owner };

[[nodiscard]] QString roleToString(Role role);
[[nodiscard]] Role    roleFromString(const QString &text);

/**
 * @brief An account that can sign in.
 *
 * Holds the password *verifier*, never the password. The entity has no
 * opinion about how the verifier is produced - that belongs to the service
 * layer behind IPasswordHasher.
 */
class User
{
public:
    User() = default;
    User(qint64 id, QString username, Role role, PasswordHash hash);

    [[nodiscard]] bool      isValid()   const { return m_id > 0 && !m_username.isEmpty(); }
    [[nodiscard]] qint64    id()        const { return m_id; }
    [[nodiscard]] QString   username()  const { return m_username; }
    [[nodiscard]] Role      role()      const { return m_role; }
    [[nodiscard]] PasswordHash passwordHash() const { return m_hash; }
    /*! Absolute path to the account's picture, or empty for the default.
        A PATH, not the bytes: an avatar is a few hundred kilobytes and would
        be read on every query of a row that is otherwise tiny. The file is
        copied into application data when it is chosen, so the record does not
        depend on a USB stick still being plugged in. */
    [[nodiscard]] QString avatarSource() const { return m_avatarSource; }

    /*!
        Profile fields. Presentation only - none of them takes part in
        authentication, and none is unique.

        Kept separate from \l username for exactly that reason: the username
        IS the credential half of the account and changing it changes what a
        person types to sign in, whereas a display name is a label. The profile
        screen showed the username in both the "Full Name" and the "Email"
        boxes because there was nowhere else to read them from, which made two
        editable fields that could not be edited.
    */
    [[nodiscard]] QString fullName() const { return m_fullName; }
    [[nodiscard]] QString email()    const { return m_email; }
    [[nodiscard]] QString phone()    const { return m_phone; }

    [[nodiscard]] int       failedAttempts() const { return m_failedAttempts; }
    [[nodiscard]] QDateTime lockedUntil()    const { return m_lockedUntil; }
    [[nodiscard]] bool      isLocked(const QDateTime &now) const;

    void setPasswordHash(PasswordHash hash) { m_hash = std::move(hash); }
    void setAvatarSource(QString path)      { m_avatarSource = std::move(path); }
    void setFullName(QString name)          { m_fullName = std::move(name); }
    void setEmail(QString email)            { m_email = std::move(email); }
    void setPhone(QString phone)            { m_phone = std::move(phone); }
    void setFailedAttempts(int attempts)    { m_failedAttempts = attempts; }
    void setLockedUntil(QDateTime until)    { m_lockedUntil = std::move(until); }

private:
    qint64       m_id = 0;
    QString      m_username;
    Role         m_role = Role::Viewer;
    PasswordHash m_hash;
    QString      m_avatarSource;
    QString      m_fullName;
    QString      m_email;
    QString      m_phone;
    int          m_failedAttempts = 0;
    QDateTime    m_lockedUntil;
};

} // namespace smarton::domain
