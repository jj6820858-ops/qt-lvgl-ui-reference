# 6. PBKDF2-HMAC-SHA512 for password storage

Status: Accepted

## Context

SmarTon signs users in against accounts held in a local SQLite file on the
panel. Anyone who can lift that file — a pulled SD card, a service laptop, a
backup — has the stored credentials offline and unlimited time to attack them.
So the question is not "is the database protected", it is "what does an
attacker get when the database is already in their hands".

Three options were on the table.

**Store the password encrypted.** Rejected outright. Encryption is reversible
by definition, so the key has to live on the same device as the ciphertext. It
converts "steal the file" into "steal the file and the binary next to it".
Anything that lets the product show a user their own password is the same
mistake wearing a different hat.

**A plain hash — SHA-256, SHA-512.** Rejected. Fast is the whole problem: a
modern GPU tries billions of SHA-256 candidates a second, so a hash of a human
password falls in minutes, and identical passwords produce identical digests
across accounts.

**A password-based KDF.** Correct by construction: deliberately slow, salted
per user, and tunable upwards as hardware improves.

Among KDFs, Argon2id is the current first choice — it is memory-hard, so GPU
and ASIC attackers lose most of their advantage. It is not in Qt. Adopting it
means vendoring a crypto library into a cross-compiled Yocto image and owning
its CVE feed for the life of the product.

## Decision

PBKDF2-HMAC-SHA512 via `QPasswordDigestor::deriveKeyPbkdf2`, at OWASP's
recommended parameters for that construction:

| Parameter | Value | Why |
|---|---|---|
| Iterations | 210,000 | OWASP guidance for PBKDF2-HMAC-SHA512 |
| Salt | 16 bytes, `QRandomGenerator::system()` | Per user; kills rainbow tables and cross-account correlation |
| Derived key | 64 bytes | The full SHA-512 output; no truncation |

The verifier is stored self-describing:

```
pbkdf2-sha512$210000$<base64 salt>$<base64 key>
```

so the parameters travel with the value. An old record verifies with its own
iteration count and is silently re-hashed with the current one on the next
successful sign-in — cost can be raised over the life of the product with no
migration and no forced password reset.

Comparison is constant time (`Pbkdf2PasswordHasher::constantTimeEquals`).
`memcmp` returns early on the first differing byte, which is measurable.

`QPasswordDigestor` lives in **Qt Network**, not Qt Core. Link `Qt6::Network`.

## Consequences

+ No decryption path exists. There is no code that could return a plaintext
  password, so no feature request can accidentally acquire one.
+ Verifying costs ~200 ms by design. `AuthViewModel` yields to the event loop
  before hashing so the busy state paints; see the comment there before moving
  it to a worker thread, because the SQLite connection is thread-affine.
+ PBKDF2 is weaker than Argon2id against GPU attack. Accepted for now because
  it ships with the toolkit; revisit the day this product takes on a crypto
  dependency for another reason. That would be a new ADR superseding this one.
+ Raising the iteration count later is a one-constant change, because the count
  is recorded per record rather than assumed.
