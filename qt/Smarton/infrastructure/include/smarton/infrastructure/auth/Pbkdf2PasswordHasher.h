#pragma once

#include <smarton/services/IPasswordHasher.h>

namespace smarton::infrastructure {

/**
 * @brief PBKDF2-HMAC-SHA512 password verifier, via Qt's QPasswordDigestor.
 *
 * Parameters follow OWASP guidance for PBKDF2-HMAC-SHA512: 210,000 iterations,
 * a 16-byte cryptographically random salt per user, and a 64-byte derived key.
 *
 * @note QPasswordDigestor lives in **Qt Network**, not Qt Core - link
 *       Qt6::Network.
 * @note PBKDF2 is chosen because Qt ships it. Argon2id resists GPU attack
 *       better; if this product ever adds a crypto dependency, revisit.
 *       See docs/adr/0006-password-hashing.md.
 */
class Pbkdf2PasswordHasher final : public services::IPasswordHasher
{
public:
    static constexpr int kIterations = 210000;
    static constexpr int kSaltBytes  = 16;
    static constexpr int kKeyBytes   = 64;

    explicit Pbkdf2PasswordHasher(int iterations = kIterations);

    [[nodiscard]] domain::PasswordHash hash(const QString &password) const override;
    [[nodiscard]] bool verify(const QString &password,
                              const domain::PasswordHash &stored) const override;
    [[nodiscard]] bool needsRehash(const domain::PasswordHash &stored) const override;

private:
    int m_iterations;
};

} // namespace smarton::infrastructure
