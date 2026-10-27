#pragma once

#include <QtCore/QByteArray>
#include <QtCore/QString>

namespace smarton::domain {

/**
 * @brief A stored password verifier. NEVER a recoverable password.
 *
 * Serialised as a self-describing string so the parameters travel with the
 * value and can be upgraded without a migration:
 *
 * @code
 * pbkdf2-sha512$210000$<base64 salt>$<base64 derived key>
 * @endcode
 *
 * Carrying the algorithm and iteration count inline means an old record can be
 * verified with its original parameters and silently re-hashed with the
 * current ones on the next successful login.
 *
 * @warning There is deliberately no way to get the password back. If a product
 *          requirement ever asks to "decrypt" a password, the requirement is
 *          wrong, not this class.
 */
class PasswordHash
{
public:
    PasswordHash() = default;
    PasswordHash(QString algorithm, int iterations, QByteArray salt, QByteArray derivedKey);

    [[nodiscard]] bool isValid() const;
    [[nodiscard]] QString    algorithm()  const { return m_algorithm; }
    [[nodiscard]] int        iterations() const { return m_iterations; }
    [[nodiscard]] QByteArray salt()       const { return m_salt; }
    [[nodiscard]] QByteArray derivedKey() const { return m_derivedKey; }

    /** Serialise to the storage form above. */
    [[nodiscard]] QString toStorage() const;

    /** Parse the storage form. Returns an invalid hash on any malformation. */
    [[nodiscard]] static PasswordHash fromStorage(const QString &encoded);

private:
    QString    m_algorithm;
    int        m_iterations = 0;
    QByteArray m_salt;
    QByteArray m_derivedKey;
};

} // namespace smarton::domain
