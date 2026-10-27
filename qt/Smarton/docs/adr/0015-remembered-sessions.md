# 15. Remembered sign-ins as rotating split tokens

Status: Accepted

## Context

The login screen has carried a "Remember information" checkbox since the first
UI pass, because frame 03 draws one. It was bound to nothing: no code read it,
so the panel asked for a username and password on every restart and the box
was decoration.

A wall panel is the worst case for this. It reboots on every power cut, it is
the only way into the home, and its owner is standing in a hallway.

## Decision

Ticking the box issues a **resume token**. The password is never stored, in any
form — ADR-0006's whole point is that this application cannot produce a
plaintext credential, and a "remember me" that reverses that would undo it.

The token is `"<selector>:<secret>"`:

* **selector** — 16 random bytes, hex, stored in the clear. A lookup key.
* **secret** — 32 bytes from `QRandomGenerator::system()`, stored only as a
  SHA-256 digest.

It expires after 30 days, is **rotated on every use** (same row, same selector,
new secret), and is revoked server-side on an explicit sign-out.

## Consequences

**Why the split.** Storing one hashed value and finding the row *by* that hash
forces the comparison into SQL, where the engine short-circuits on the first
differing byte. Splitting lets the row be found by an indexed equality on a
value that protects nothing, and the actual credential compared in constant
time in C++ — `constantTimeEquals()` in `AuthService.cpp`. One extra column.

**Why SHA-256 and not PBKDF2.** These look like the same problem and are not.
A password is low-entropy and human-chosen, so a stolen verifier is guessable
and the defence is to make each guess expensive — that is what 210,000
iterations buy. A session secret is 32 bytes of CSPRNG output; there is nothing
to guess and no dictionary to run, so iteration count buys nothing and costs
latency on every restart. Hashing still earns its keep: a leaked database is
not a pile of usable tokens.

**Rotation is what bounds a copied settings file.** The token lives in
QSettings, which on the panel is a file with the same protection as the
database beside it. Without a secure element there is no way to do better
locally, so the token is defended by being short-lived, single-use and
revocable rather than by being hidden. A copy lifted off the disk works until
the panel next starts and then stops — and the legitimate panel's next resume
fails, which is a detectable event rather than a silent one.

**A bad token is not a failed password.** `resumeSession()` never increments
the failed-attempt counter and never returns `AccountLocked` from a bad token.
Otherwise anyone who can reach the panel could lock its owner out without
knowing so much as a username. A token presented against an account that is
*already* locked is still refused: the token proves the device was trusted
once, not that a lockout should be overridden.

**A valid selector with a wrong secret deletes the row.** Nobody types these,
so that combination is not a typo — it means a stale or forged copy is being
probed. Better to make the real user sign in once than to leave a live token
under attack.

**The idle lock had to be reconciled with this, and it is the interesting
part.** The two features protect different things: the idle lock protects a
*running* panel from a passer-by; remembering saves the owner retyping after a
*restart*. They collide because anyone who can reach the screen can reach the
power lead — so a remembered session would sign itself straight back in after a
power cycle, and the idle lock would become decorative.

Revoking the token on idle lock does not work either: with a five-minute idle
lock on a hallway panel it fires constantly, so "remember me" would never
survive to be used.

The resolution is to persist the LOCK rather than destroy the token.
`ISessionTokenStore::lockedForInactivity` is set when the idle timer fires,
written through immediately (a lock that is still in a settings cache when the
power goes out has not happened), and cleared by exactly one thing: a
successful password entry. `tryResumeSession()` checks it before it even reads
the token. So a power cycle after an idle lock lands on the password prompt
exactly as the lock intended, and the user stays remembered for the next clean
start.

**The token store is its own interface, not part of IPreferences.** What is
kept there is a bearer credential, not an operator preference. Behind its own
interface, moving it to a platform keychain later is one new implementation and
one line in `main.cpp`, instead of a hunt through a settings class for which of
its fields were secrets.

**The username is stored separately from the token** and outlives it, so an
expired session still lands on a form that needs only the password rather than
on two empty fields.

**Resume happens before the QML engine loads.** A login screen that flashes
past is worse than one that never appears, so `main.cpp` attempts the resume
and `Main.qml` reads `signedIn` to choose its initial item.

## Alternatives considered

**Store the password, encrypted.** Rejected. The key would sit next to the
ciphertext on the same filesystem, which is encoding, not encryption — and it
would give the application something ADR-0006 exists to ensure it never has.

**A long-lived token with no expiry.** Rejected: a panel taken out of service,
sold or binned would remain a working key to the home indefinitely.

**No rotation.** Rejected: without it, a settings file copied once is valid for
the full 30 days and its use is undetectable.
