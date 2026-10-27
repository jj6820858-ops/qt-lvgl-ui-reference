#include <smarton/infrastructure/auth/Pbkdf2PasswordHasher.h>

#include <QtCore/QCryptographicHash>
#include <QtCore/QRandomGenerator>
#include <QtNetwork/QPasswordDigestor>

namespace smarton::infrastructure {

namespace {

constexpr auto kAlgorithm = "pbkdf2-sha512";

/**
 * Compare two byte arrays in time independent of where they first differ.
 *
 * A plain == returns as soon as it finds a mismatch, so an attacker can learn
 * the correct prefix byte by byte from response timing. Qt has no public
 * constant-time compare, so accumulate differences across the FULL length and
 * only then reduce to a boolean.
 */
bool constantTimeEquals(const QByteArray &a, const QByteArray &b)
{
    if (a.size() != b.size())
        return false;

    // volatile stops the compiler from short-circuiting the loop.
    volatile quint8 diff = 0;
    for (int i = 0; i < a.size(); ++i)
        diff = static_cast<quint8>(diff | (static_cast<quint8>(a[i]) ^ static_cast<quint8>(b[i])));

    return diff == 0;
}

QByteArray randomSalt(int bytes)
{
    QByteArray salt(bytes, Qt::Uninitialized);
    // system() is the CSPRNG. QRandomGenerator::global() is NOT guaranteed to
    // be cryptographically secure and must never be used for a salt.
    QRandomGenerator::system()->generate(salt.begin(), salt.end());
    return salt;
}

QByteArray derive(const QString &password, const QByteArray &salt, int iterations)
{
    return QPasswordDigestor::deriveKeyPbkdf2(
        QCryptographicHash::Sha512,
        password.toUtf8(),
        salt,
        iterations,
        Pbkdf2PasswordHasher::kKeyBytes);
}

} // namespace

Pbkdf2PasswordHasher::Pbkdf2PasswordHasher(int iterations)
    : m_iterations(iterations > 0 ? iterations : kIterations)
{
}

domain::PasswordHash Pbkdf2PasswordHasher::hash(const QString &password) const
{
    const QByteArray salt = randomSalt(kSaltBytes);
    return domain::PasswordHash(QString::fromLatin1(kAlgorithm), m_iterations,
                                salt, derive(password, salt, m_iterations));
}

bool Pbkdf2PasswordHasher::verify(const QString &password,
                                  const domain::PasswordHash &stored) const
{
    if (!stored.isValid() || stored.algorithm() != QLatin1String(kAlgorithm))
        return false;

    // Verify with the parameters recorded in the stored value, not the current
    // policy - otherwise raising the cost would invalidate every old password.
    const QByteArray candidate = derive(password, stored.salt(), stored.iterations());
    return constantTimeEquals(candidate, stored.derivedKey());
}

bool Pbkdf2PasswordHasher::needsRehash(const domain::PasswordHash &stored) const
{
    return !stored.isValid()
        || stored.algorithm() != QLatin1String(kAlgorithm)
        || stored.iterations() < m_iterations;
}

} // namespace smarton::infrastructure
