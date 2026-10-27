#pragma once

#include <smarton/domain/valueobjects/PasswordHash.h>

namespace smarton::services {

/**
 * @brief Turns a plaintext password into a verifier, and checks one.
 *
 * An interface so the KDF and its cost parameters can be swapped - and so the
 * service layer can be tested with a fast fake instead of paying 210,000
 * iterations in every unit test.
 */
class IPasswordHasher
{
public:
    virtual ~IPasswordHasher() = default;

    /** Produce a verifier with a freshly generated random salt. */
    [[nodiscard]] virtual domain::PasswordHash hash(const QString &password) const = 0;

    /**
     * Check @p password against @p stored using the parameters recorded in
     * @p stored. Implementations MUST compare in constant time.
     */
    [[nodiscard]] virtual bool verify(const QString &password,
                                      const domain::PasswordHash &stored) const = 0;

    /**
     * True when @p stored used weaker parameters than the current policy, so
     * the caller can transparently re-hash after a successful login.
     */
    [[nodiscard]] virtual bool needsRehash(const domain::PasswordHash &stored) const = 0;
};

} // namespace smarton::services
