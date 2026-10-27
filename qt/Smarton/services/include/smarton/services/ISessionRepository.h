#pragma once

#include <QtCore/QDateTime>
#include <QtCore/QString>

#include <optional>

namespace smarton::services {

/**
 * @brief One remembered sign-in, as the DATABASE holds it.
 *
 * SPLIT TOKEN. What the panel keeps on disk is "<selector>:<secret>". Only the
 * selector is stored here in the clear; the secret is stored as a hash. That
 * split exists so the two halves can be treated differently:
 *
 *  - the SELECTOR is a lookup key, so the row can be found with an ordinary
 *    indexed equality;
 *  - the SECRET is a credential, so it is compared in constant time in C++,
 *    where a constant-time compare is actually possible.
 *
 * Storing one hashed value and looking the row up BY that hash would force the
 * comparison into SQL, where the engine short-circuits on the first differing
 * byte and the query planner is free to do whatever it likes. Splitting is the
 * standard answer and costs one extra column.
 */
struct StoredSession
{
    qint64    id = 0;
    qint64    userId = 0;
    /** Public half. Identifies the row; proves nothing. */
    QString   selector;
    /** SHA-256 of the secret half, hex. See ISessionRepository's note on why
        this is not PBKDF2. */
    QString   secretHash;
    QDateTime issuedAt;
    QDateTime expiresAt;
    QDateTime lastUsedAt;

    [[nodiscard]] bool isValid() const { return id > 0 && userId > 0; }
};

/**
 * @brief Storage for remembered sign-ins. Declared here, implemented in
 *        infrastructure, so AuthService can be tested with no database.
 *
 * WHY THESE ARE HASHED WITH SHA-256 AND NOT PBKDF2. The two look like the same
 * problem and are not. A password is low-entropy and human-chosen, so a stolen
 * verifier is guessable and the defence is to make each guess expensive - that
 * is what ADR-0006's 210,000 PBKDF2 iterations buy. A session secret is 32
 * bytes straight from the system CSPRNG; there is nothing to guess and no
 * dictionary to run, so iteration count buys nothing and would only add
 * latency to every restart. What hashing DOES buy here is that a leaked
 * database is not a pile of usable tokens, and a single fast digest is
 * sufficient for that.
 */
class ISessionRepository
{
public:
    virtual ~ISessionRepository() = default;

    [[nodiscard]] virtual std::optional<StoredSession>
        findBySelector(const QString &selector) = 0;

    /** Assigns and returns the row id, or 0 on failure. */
    virtual qint64 insert(const StoredSession &session) = 0;

    /** Rotation: a new secret and expiry for an existing row. */
    virtual bool rotate(qint64 id, const QString &secretHash,
                        const QDateTime &expiresAt, const QDateTime &lastUsedAt) = 0;

    virtual bool remove(qint64 id) = 0;
    /** Every remembered sign-in for one account. Used by "sign out". */
    virtual bool removeAllForUser(qint64 userId) = 0;
    /** Housekeeping; returns how many rows went. */
    virtual int purgeExpired(const QDateTime &now) = 0;
};

} // namespace smarton::services
