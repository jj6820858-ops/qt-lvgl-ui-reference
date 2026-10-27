# 12. SQLite by default, any Qt SQL driver by configuration

Status: Accepted

## Context

The persistence layer named `QSQLITE` in two places and used two
SQLite-specific statements. A request to run against MySQL had no answer
except "rewrite the repositories".

The instinct to just switch to MySQL is worth resisting for the panel itself.
A wall unit that cannot reach a database server is a wall unit that cannot
turn on a light. SQLite is a file, needs no server, survives a power cut with
WAL, and adds nothing to a 1 GB Yocto image. For an appliance that is not a
compromise, it is the correct answer.

But MySQL is a fair request for the other cases: a household with several
panels wanting one shared model, or a workstation dashboard.

## Decision

The driver is configuration. `DatabaseConfig::fromUrl()` accepts:

```
/var/lib/smarton/accounts.db          → SQLite (a bare path still works)
sqlite:/var/lib/smarton/accounts.db   → SQLite
mysql://user:pw@host:3306/smarton     → QMYSQL
postgres://user:pw@host:5432/smarton  → QPSQL
```

passed as `--database`. SQLite remains the default and the only one the
embedded build is tested against.

Almost nothing had to change, because the repositories were already written
against `QSqlDatabase` with prepared statements and bound values throughout.
Exactly three things were dialect-specific, and all three are now isolated:

| Concern | SQLite | Server |
|---|---|---|
| Auto-increment | `INTEGER PRIMARY KEY AUTOINCREMENT` | `AUTO_INCREMENT` / `BIGSERIAL` |
| Case-insensitive username | `COLLATE NOCASE` | default / `CITEXT` |
| Upsert | `INSERT OR REPLACE` | `REPLACE INTO` / `ON CONFLICT` |
| "now" | `datetime('now')` | `CURRENT_TIMESTAMP` |

`TEXT` columns became `VARCHAR(n)` where a server needs a length for an index.

The driver is checked with `QSqlDatabase::isDriverAvailable()` before use and
the error names the missing driver — "driver not loaded" with no driver name
is one of the least useful messages Qt produces.

## Consequences

+ MySQL is a command-line flag, and the code that had to change to allow it is
  four short branches rather than a second repository.
+ The error path for a missing driver is explicit instead of a Qt warning.
− Only SQLite is covered by tests and by CI. MySQL is *supported*, not
  *verified*: nobody has run the suite against a server, and the schema has
  not been checked against a real MySQL strict mode.
− Passwords appear in a connection URL. `describe()` never logs them, but a
  URL in a shell history or a process list is a real exposure. A server
  deployment should use a config file with restricted permissions, which is
  another reason the panel stays on SQLite.
