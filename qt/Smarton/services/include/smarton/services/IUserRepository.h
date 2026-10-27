#pragma once

#include <smarton/domain/entities/User.h>

#include <optional>

namespace smarton::services {

/**
 * @brief Storage for accounts. Declared here, implemented in infrastructure.
 *
 * The service layer never knows whether this is SQLite, a REST API or an
 * in-memory fake - which is what lets AuthService be tested with no database.
 */
class IUserRepository
{
public:
    virtual ~IUserRepository() = default;

    [[nodiscard]] virtual std::optional<domain::User>
        findByUsername(const QString &username) = 0;

    /**
     * By primary key, for resuming a remembered session.
     *
     * A remembered session names the account by ID rather than by username,
     * so that renaming an account does not silently orphan every panel that
     * had remembered it - and, more importantly, so a session row can never
     * be made to point at a DIFFERENT account by creating one with the old
     * name. The ID is the thing that does not get reused.
     */
    [[nodiscard]] virtual std::optional<domain::User> findById(qint64 id) = 0;

    /** Persist lockout counters and any re-hashed verifier. */
    virtual bool save(const domain::User &user) = 0;

    /**
     * @brief Insert a new account.
     * @return the new row id, or 0 on failure (a duplicate username included).
     *
     * Returns the ID rather than a bool because the caller needs it: a member
     * record links to the account by id, and looking it back up by username
     * would be a second query racing anything that renames in between.
     *
     * On the INTERFACE rather than only on the SQLite class because
     * AuthService creates accounts now, and AuthService must stay testable
     * without a database.
     */
    virtual qint64 createUser(const QString &username,
                              const domain::PasswordHash &hash,
                              domain::Role role) = 0;

    [[nodiscard]] virtual bool isEmpty() = 0;
};

} // namespace smarton::services
