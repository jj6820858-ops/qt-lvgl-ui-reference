#pragma once

#include <smarton/infrastructure/persistence/DatabaseConfig.h>
#include <smarton/services/IUserRepository.h>

#include <QtSql/QSqlDatabase>
#include <QtSql/QSqlQuery>

namespace smarton::infrastructure {

/**
 * @brief Account storage in SQLite.
 *
 * @note The schema stores a password VERIFIER, never a password. There is no
 *       column that could be decrypted back to a plaintext credential.
 * @note Every statement is a prepared statement with bound values. String
 *       concatenation into SQL is banned in this class - that is how SQL
 *       injection gets in.
 */
class SqliteUserRepository final : public services::IUserRepository
{
public:
    explicit SqliteUserRepository(QString connectionName = QStringLiteral("smarton"));
    ~SqliteUserRepository() override;

    /** Opens @p path as SQLite (created if absent) and applies the schema. */
    [[nodiscard]] bool open(const QString &path);
    /** Opens whatever @p config describes - SQLite, MySQL, PostgreSQL. */
    [[nodiscard]] bool open(const DatabaseConfig &config);
    void close();

    [[nodiscard]] bool isOpen() const { return m_db.isOpen(); }
    [[nodiscard]] QString lastError() const { return m_lastError; }

    [[nodiscard]] std::optional<domain::User>
        findByUsername(const QString &username) override;
    [[nodiscard]] std::optional<domain::User> findById(qint64 id) override;
    bool save(const domain::User &user) override;
    [[nodiscard]] bool isEmpty() override;

    /** Insert a new account. Returns 0 if the username already exists. */
    qint64 createUser(const QString &username,
                      const domain::PasswordHash &hash,
                      domain::Role role) override;

private:
    /** Row -> User. Shared by findByUsername() and findById() so the two
        cannot read different sets of columns. */
    [[nodiscard]] static domain::User hydrate(const QSqlQuery &query);

    [[nodiscard]] bool applySchema();
    /** Add columns introduced after the first release. */
    [[nodiscard]] bool migrate();
    /** AUTOINCREMENT is SQLite's spelling; servers use AUTO_INCREMENT or a
        sequence. The only dialect difference in the whole schema. */
    [[nodiscard]] QString primaryKeyClause() const;

    DatabaseConfig m_config;

    QSqlDatabase m_db;
    QString      m_connectionName;
    QString      m_lastError;
};

} // namespace smarton::infrastructure
