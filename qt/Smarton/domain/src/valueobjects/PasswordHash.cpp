#include <smarton/domain/valueobjects/PasswordHash.h>

#include <QtCore/QStringList>

#include <utility>

namespace smarton::domain {

PasswordHash::PasswordHash(QString algorithm, int iterations,
                           QByteArray salt, QByteArray derivedKey)
    : m_algorithm(std::move(algorithm))
    , m_iterations(iterations)
    , m_salt(std::move(salt))
    , m_derivedKey(std::move(derivedKey))
{
}

bool PasswordHash::isValid() const
{
    return !m_algorithm.isEmpty() && m_iterations > 0
        && !m_salt.isEmpty() && !m_derivedKey.isEmpty();
}

QString PasswordHash::toStorage() const
{
    if (!isValid())
        return {};

    return QStringLiteral("%1$%2$%3$%4")
        .arg(m_algorithm)
        .arg(m_iterations)
        .arg(QString::fromLatin1(m_salt.toBase64()),
             QString::fromLatin1(m_derivedKey.toBase64()));
}

PasswordHash PasswordHash::fromStorage(const QString &encoded)
{
    const QStringList parts = encoded.split(QLatin1Char('$'));
    if (parts.size() != 4)
        return {};

    bool ok = false;
    const int iterations = parts.at(1).toInt(&ok);
    if (!ok || iterations <= 0)
        return {};

    const QByteArray salt = QByteArray::fromBase64(parts.at(2).toLatin1());
    const QByteArray key  = QByteArray::fromBase64(parts.at(3).toLatin1());
    if (salt.isEmpty() || key.isEmpty())
        return {};

    return PasswordHash(parts.at(0), iterations, salt, key);
}

} // namespace smarton::domain
