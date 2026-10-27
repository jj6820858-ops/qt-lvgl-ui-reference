#include <smarton/infrastructure/auth/Pbkdf2PasswordHasher.h>
#include <smarton/infrastructure/persistence/DatabaseConfig.h>
#include <smarton/infrastructure/persistence/FileActivityStore.h>
#include <smarton/infrastructure/persistence/SqliteHomeStore.h>
#include <smarton/infrastructure/media/FileAvatarStore.h>
#include <smarton/infrastructure/settings/QSettingsPreferences.h>
#include <smarton/infrastructure/settings/QSettingsSessionTokenStore.h>
#include <smarton/infrastructure/persistence/SqliteSessionRepository.h>
#include <smarton/infrastructure/transport/LoopbackDeviceTransport.h>
#ifdef ST_HAS_MQTT
#  include <smarton/infrastructure/transport/MqttDeviceTransport.h>
#endif
#include <smarton/infrastructure/persistence/SqliteUserRepository.h>
#include <smarton/backend/theme/Appearance.h>
#include <smarton/models/ActivityListModel.h>
#include <smarton/models/AuthViewModel.h>
#include <smarton/models/HomeViewModel.h>
#include <smarton/services/AuthService.h>
#include <smarton/services/HomeService.h>
#include <smarton/services/ActivityLog.h>
#include <smarton/services/SceneScheduler.h>

#include <QtCore/QCommandLineOption>
#include <QtCore/QCommandLineParser>
#include <QtCore/QDir>
#include <QtCore/QLoggingCategory>
#include <QtCore/QLibraryInfo>
#include <QtCore/QLocale>
#include <QtCore/QStandardPaths>
#include <QtCore/QStringList>
#include <QtCore/QUrl>
#include <QtCore/QTranslator>
#include <QtCore/QTextStream>
#include <QtGui/QGuiApplication>
#include <QtGui/QSurfaceFormat>
#include <QtGui/QWindow>
#include <QtQml/QQmlApplicationEngine>
#include <QtQuick/QQuickWindow>
#include <QtQuickControls2/QQuickStyle>

#include <optional>

#include <cstdio>

#ifdef Q_OS_WIN
#  include <windows.h>
#else
#  include <termios.h>
#  include <unistd.h>
#endif

using namespace smarton;

namespace {

Q_LOGGING_CATEGORY(lcBoot, "smarton.boot")

/*!
    Where the account database lives.

    AppDataLocation, not the working directory: on the panel the binary sits on
    a read-only rootfs, and on a developer machine writing a database next to
    the executable puts credentials inside the build tree, where they get
    committed by accident.
*/
QString accountDatabasePath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/accounts.db");
}

/*! Read the broker endpoint without placing credentials in process arguments.

    The systemd unit loads SMARTON_MQTT_* from a root-only EnvironmentFile.
    `--transport` remains available for development, but an endpoint supplied
    through the environment is the deployment path. */
#ifdef ST_HAS_MQTT
QUrl brokerUrlFromEnvironment()
{
    const QString endpoint = qEnvironmentVariable("SMARTON_MQTT_URL").trimmed();
    if (endpoint.isEmpty())
        return {};

    QUrl url(endpoint);
    if (!url.isValid() || url.host().isEmpty())
        return {};
    url.setUserName(qEnvironmentVariable("SMARTON_MQTT_USERNAME"));
    url.setPassword(qEnvironmentVariable("SMARTON_MQTT_PASSWORD"));
    return url;
}
#endif

/*!
    Read a password from the terminal without echoing it.

    Not from argv: command lines are visible to every process on the machine
    via ps, and land in shell history. Not from a Qt dialog either - this runs
    before the GUI exists, which is the point.
*/
QString readSecretFromTerminal(const QString &prompt)
{
    QTextStream out(stdout);
    out << prompt << Qt::flush;

    bool restored = false;
#ifdef Q_OS_WIN
    HANDLE handle = GetStdHandle(STD_INPUT_HANDLE);
    DWORD mode = 0;
    if (GetConsoleMode(handle, &mode)) {
        SetConsoleMode(handle, mode & ~static_cast<DWORD>(ENABLE_ECHO_INPUT));
        restored = true;
    }
#else
    termios previous {};
    if (::tcgetattr(STDIN_FILENO, &previous) == 0) {
        termios quiet = previous;
        quiet.c_lflag &= ~static_cast<tcflag_t>(ECHO);
        ::tcsetattr(STDIN_FILENO, TCSAFLUSH, &quiet);
        restored = true;
    }
#endif

    QTextStream in(stdin);
    const QString secret = in.readLine();

#ifdef Q_OS_WIN
    if (restored)
        SetConsoleMode(handle, mode);
#else
    if (restored)
        ::tcsetattr(STDIN_FILENO, TCSAFLUSH, &previous);
#endif

    out << Qt::endl;
    return secret;
}

/*!
    `smarton --create-account <name>` - provision an account and exit.

    This exists because the environment-variable path below is invisible to the
    two ways people actually launch a desktop build: Qt Creator does not pass
    the shell's environment, and double-clicking a macOS .app does not either.
    An operator who cannot see stderr then gets "incorrect password" forever
    for an account that was never created.

    Returns the process exit code.
*/
int createAccountInteractively(infrastructure::SqliteUserRepository &users,
                               const services::IPasswordHasher &hasher,
                               const QString &username)
{
    QTextStream out(stdout);

    const QString password = readSecretFromTerminal(
        QStringLiteral("Password for '%1': ").arg(username));
    const QString again = readSecretFromTerminal(QStringLiteral("Repeat password: "));

    if (password != again) {
        out << "Passwords do not match. No account created." << Qt::endl;
        return 1;
    }
    if (!models::AuthViewModel::isAcceptablePassword(password)) {
        out << "Password must be at least 8 characters, with upper and lower case "
               "and a digit or symbol. No account created." << Qt::endl;
        return 1;
    }
    if (users.createUser(username, hasher.hash(password), domain::Role::Administrator) <= 0) {
        out << "Could not create the account: " << users.lastError() << Qt::endl;
        return 1;
    }

    out << "Created administrator account '" << username << "'." << Qt::endl;
    return 0;
}

/*!
    Create the first administrator when the database is new.

    The password is NOT hard-coded and there is no default. It is read from
    SMARTON_BOOTSTRAP_PASSWORD, and if that is unset the run refuses to
    provision an account and says so. A shipped default credential is the
    single most common way an embedded product gets owned, and "we document
    that you should change it" has never once been enough.

    This is the unattended path, for a panel on first boot. Interactively, use
    --create-account, which does not depend on the launcher passing an
    environment through.
*/
bool provisionFirstAccount(infrastructure::SqliteUserRepository &users,
                           const services::IPasswordHasher &hasher)
{
    if (!users.isEmpty())
        return true;

    const QByteArray fromEnv = qgetenv("SMARTON_BOOTSTRAP_PASSWORD");
    if (fromEnv.isEmpty()) {
        qCWarning(lcBoot).noquote()
            << "No accounts exist and SMARTON_BOOTSTRAP_PASSWORD is not set.\n"
               "  Set it once to create the first administrator, for example:\n"
               "    SMARTON_BOOTSTRAP_PASSWORD='<a password you choose>' ./smarton\n"
               "  The value is used once, hashed with PBKDF2-HMAC-SHA512, and never stored.";
        return false;
    }

    const QString password = QString::fromUtf8(fromEnv);
    if (!models::AuthViewModel::isAcceptablePassword(password)) {
        qCWarning(lcBoot) << "SMARTON_BOOTSTRAP_PASSWORD does not meet the password policy "
                             "(8+ characters, mixed case, and a number or symbol).";
        return false;
    }

    const QString username = QString::fromUtf8(qgetenv("SMARTON_BOOTSTRAP_USER"));
    const QString account = username.isEmpty() ? QStringLiteral("admin") : username;

    if (users.createUser(account, hasher.hash(password), domain::Role::Administrator) <= 0) {
        qCWarning(lcBoot) << "Could not create the first account:" << users.lastError();
        return false;
    }

    qCInfo(lcBoot) << "Created the first administrator account:" << account;
    return true;
}

/*!
    Install the UI translation and Qt's own, for @p locale.

    Both matter: without the Qt catalogue, the strings Qt supplies itself -
    dialog buttons, input-method text, the standard shortcuts - stay English
    while everything around them translates, which looks worse than a fully
    untranslated app.

    Translators are parented to the application so they outlive this call;
    a QTranslator that goes out of scope silently un-installs itself, which is
    the classic reason "translations work in a test and not in main".
*/
void installTranslations(QGuiApplication &app, const QLocale &locale)
{
    auto *appCatalogue = new QTranslator(&app);
    // qt_add_translations() embeds the .qm files at :/i18n by default.
    if (appCatalogue->load(locale, QStringLiteral("smarton"), QStringLiteral("_"),
                           QStringLiteral(":/i18n"))) {
        QCoreApplication::installTranslator(appCatalogue);
        qCInfo(lcBoot) << "Loaded UI translation for" << locale.name();
    } else if (locale.language() != QLocale::English) {
        // English is the source language, so a missing catalogue is expected
        // and not worth a warning. Any other locale falling back is.
        qCWarning(lcBoot) << "No UI translation for" << locale.name()
                          << "- falling back to the source strings.";
    }

    auto *qtCatalogue = new QTranslator(&app);
    if (qtCatalogue->load(locale, QStringLiteral("qtbase"), QStringLiteral("_"),
                          QLibraryInfo::path(QLibraryInfo::TranslationsPath))) {
        QCoreApplication::installTranslator(qtCatalogue);
    }
}

/*!
    MSAA sample count, read from the raw argv.

    QSurfaceFormat::setDefaultFormat() has to be called BEFORE the application
    is constructed to affect the windows it creates, and QCommandLineParser
    needs an application to exist before it can parse anything. One of the two
    has to read argv by hand; it is far less bad for it to be this, which
    understands exactly one option and gets the number wrong safely.

    Zero by default, and that is not an oversight. Qt Quick antialiases
    rounded rectangles and paths in the vertex shader already, which is what
    makes the tiles' corners smooth; MSAA on top of that buys the 3D map's
    edges and costs a full-screen multisample buffer, which on the panel's
    Mali GPU is memory bandwidth it does not have to spare.
*/
int msaaFromArgv(int argc, char **argv)
{
    for (int i = 1; i < argc; ++i) {
        const QString argument = QString::fromLocal8Bit(argv[i]);
        QString value;
        if (argument.startsWith(QLatin1String("--msaa=")))
            value = argument.mid(7);
        else if (argument == QLatin1String("--msaa") && i + 1 < argc)
            value = QString::fromLocal8Bit(argv[++i]);
        else
            continue;

        bool parsed = false;
        const int samples = value.toInt(&parsed);
        // 2, 4, 8. Anything else is a typo, and silently honouring 3 samples
        // means a driver quietly rounding it to something else.
        if (parsed && (samples == 2 || samples == 4 || samples == 8))
            return samples;
        return 0;
    }
    return 0;
}

} // namespace

int main(int argc, char *argv[])
{
    // Before the application, because the default surface format has to be in
    // place before it creates any window.
    const int msaaSamples = msaaFromArgv(argc, argv);
    if (msaaSamples > 0) {
        QSurfaceFormat format = QSurfaceFormat::defaultFormat();
        format.setSamples(msaaSamples);
        QSurfaceFormat::setDefaultFormat(format);
    }

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral(ST_APPLICATION_NAME));
    QGuiApplication::setApplicationDisplayName(QStringLiteral(ST_DISPLAY_NAME));
    QGuiApplication::setOrganizationName(QStringLiteral(ST_ORGANIZATION));
    QGuiApplication::setOrganizationDomain(QStringLiteral(ST_DOMAIN));
    QGuiApplication::setApplicationVersion(QStringLiteral(ST_VERSION));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral(ST_DISPLAY_NAME));
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption databaseOption(
        QStringLiteral("database"),
        QStringLiteral("Database to use. A path for SQLite, or a URL: "
                       "mysql://user:pass@host:3306/smarton. Defaults to a "
                       "SQLite file in the per-user data location."),
        QStringLiteral("path-or-url"));
    parser.addOption(databaseOption);
    const QCommandLineOption createAccountOption(
        QStringLiteral("create-account"),
        QStringLiteral("Create an administrator account and exit. Prompts for the "
                       "password on the terminal; never takes it on the command line."),
        QStringLiteral("username"));
    parser.addOption(createAccountOption);
    const QCommandLineOption localeOption(
        QStringLiteral("lang"),
        QStringLiteral("Force a UI locale, e.g. de_DE. Defaults to the system locale."),
        QStringLiteral("locale"));
    parser.addOption(localeOption);
    const QCommandLineOption idleOption(
        QStringLiteral("idle-lock"),
        QStringLiteral("Seconds of inactivity before the panel locks. 0 disables."),
        QStringLiteral("seconds"));
    parser.addOption(idleOption);
    const QCommandLineOption transportOption(
        QStringLiteral("device-failure-rate"),
        QStringLiteral("0.0-1.0 of simulated device commands to drop, for "
                       "exercising the offline and retry paths. Default 0."),
        QStringLiteral("rate"));
    parser.addOption(transportOption);
    const QCommandLineOption brokerOption(
        QStringLiteral("transport"),
        QStringLiteral("mqtt://[user:pass@]host[:port] to talk to real devices "
                       "through an MQTT broker. Omitted, the panel runs against "
                       "the in-process loopback."),
        QStringLiteral("url"));
    parser.addOption(brokerOption);
    // Parsed for real above, from argv. Declared here so --help documents it
    // and so an unknown-option error is not raised for something we honour.
    const QCommandLineOption msaaOption(
        QStringLiteral("msaa"),
        QStringLiteral("Multisample antialiasing: 2, 4 or 8. Off by default - "
                       "Qt Quick already antialiases rounded geometry, and a "
                       "multisample buffer costs the panel's GPU bandwidth it "
                       "does not have."),
        QStringLiteral("samples"));
    parser.addOption(msaaOption);
    const QCommandLineOption noSchedulerOption(
        QStringLiteral("no-scheduler"),
        QStringLiteral("Do not run scenes on their schedules."));
    parser.addOption(noSchedulerOption);
    parser.process(app);

    // Command line beats the stored preference beats the system locale.
    infrastructure::QSettingsPreferences bootPreferences;
    const QString preferredLocale = parser.isSet(localeOption)
                                        ? parser.value(localeOption)
                                        : bootPreferences.locale();
    installTranslations(app, preferredLocale.isEmpty() ? QLocale::system()
                                                       : QLocale(preferredLocale));

    // Basic, not the native style: the theme is ours, and Qt's own guidance is
    // never to customise the native Windows/macOS styles.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    // ---- graphics ------------------------------------------------------------
    // THE PLATFORM PLUGIN DECIDES, and this only makes the decision explicit
    // where it matters. On a direct-to-framebuffer plugin - which is what the
    // panel runs - the scene graph has exactly one usable backend and naming
    // it removes a runtime probe that can pick a software fallback if the GL
    // driver is slow to answer. Everywhere else the default is right: forcing
    // OpenGL on macOS would swap a first-class Metal backend for a deprecated
    // one, which is the opposite of using the hardware.
    //
    // Called before the engine, because the graphics API cannot change once a
    // window exists.
    const QString platform = QGuiApplication::platformName().toLower();
    const bool directToFramebuffer =
        platform.contains(QLatin1String("eglfs"))
        || platform.contains(QLatin1String("linuxfb"))
        || platform.contains(QLatin1String("kms"));
    const bool softwareRenderer =
        qEnvironmentVariable("QT_QUICK_BACKEND").compare(
            QLatin1String("software"), Qt::CaseInsensitive) == 0;
    if (softwareRenderer)
        QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);
    else if (directToFramebuffer)
        QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    qCInfo(lcBoot).noquote()
        << "Graphics: platform" << platform
        << (softwareRenderer ? "· scene graph pinned to software"
                             : directToFramebuffer ? "· scene graph pinned to OpenGL"
                                                   : "· scene graph backend chosen by Qt")
        << (msaaSamples > 0 ? QStringLiteral("· MSAA %1x").arg(msaaSamples)
                            : QStringLiteral("· MSAA off (Qt Quick antialiases "
                                             "rounded geometry on its own)"));

    // ---- composition root ---------------------------------------------------
    // The only place that knows how the layers fit together. Every other file
    // receives what it needs, which is what makes them testable in isolation.
    // Operator preferences live in QSettings, not the database: they must
    // survive a factory reset of the home model, and on the panel they should
    // be inspectable without a SQL client.
    infrastructure::QSettingsPreferences preferences;
    qCInfo(lcBoot).noquote() << "Preferences:" << preferences.fileName();

    const infrastructure::DatabaseConfig dbConfig =
        infrastructure::DatabaseConfig::fromUrl(parser.value(databaseOption),
                                                accountDatabasePath());
    qCInfo(lcBoot).noquote() << "Database:" << dbConfig.describe();

    infrastructure::SqliteUserRepository users;
    if (!users.open(dbConfig)) {
        qCCritical(lcBoot) << "Cannot open the database:" << users.lastError();
        return 1;
    }

    const infrastructure::Pbkdf2PasswordHasher hasher;

    if (parser.isSet(createAccountOption))
        return createAccountInteractively(users, hasher, parser.value(createAccountOption));

    provisionFirstAccount(users, hasher);

    // Remembered sign-ins. Same database as the accounts, its own connection -
    // see SqliteSessionRepository for why. A failure here is not fatal: the
    // panel simply asks for a password every time, which is the safe way to
    // degrade.
    infrastructure::SqliteSessionRepository sessions;
    if (!sessions.open(dbConfig))
        qCWarning(lcBoot) << "Remembered sign-ins unavailable:" << sessions.lastError();

    infrastructure::QSettingsSessionTokenStore sessionTokens;

    infrastructure::FileAvatarStore avatars;
    services::AuthService auth(users, hasher);
    auth.setAvatarStore(&avatars);
    if (sessions.isOpen())
        auth.setSessionRepository(&sessions);

    // Auto-lock. A wall panel is not a laptop: it sits unattended in a hallway
    // and anyone walking past inherits the session. Default five minutes;
    // --idle-lock 0 turns it off for a demo or a kiosk in a locked room.
    bool idleParsed = false;
    const int idleSeconds = parser.isSet(idleOption)
                                ? parser.value(idleOption).toInt(&idleParsed)
                                : preferences.idleLockSeconds();
    if (parser.isSet(idleOption) && !idleParsed)
        qCWarning(lcBoot) << "Ignoring --idle-lock: not a number.";
    else
        auth.setIdleTimeoutSeconds(idleSeconds);

    models::AuthViewModel authViewModel;
    authViewModel.setService(&auth);
    // The Preferences tab can now change the auto-lock, and this is what makes
    // the choice outlive the process. The view model announces; the root
    // writes - it is the only object here that owns the settings file.
    QObject::connect(&authViewModel, &models::AuthViewModel::idleLockSecondsChanged,
                     &app, [&preferences, &authViewModel] {
                         preferences.setIdleLockSeconds(authViewModel.idleLockSeconds());
                     });
    authViewModel.setSessionTokenStore(&sessionTokens);

    // Attempted BEFORE the engine loads, so a remembered panel never paints
    // the login screen at all - a login form that flashes past is worse than
    // one that never appears. Main.qml reads authViewModel.signedIn to decide
    // which screen it starts on, so by here the answer is already settled.
    if (authViewModel.tryResumeSession())
        qCInfo(lcBoot).noquote() << "Resumed the remembered session for"
                                 << authViewModel.currentUserName();

    // The home model shares the account database's connection: one file, one
    // connection, one thread. The seed is the FACTORY DEFAULT - once the user
    // has changed anything, the stored snapshot is the model.
    infrastructure::SqliteHomeStore homeStore;
    homeStore.setDriver(dbConfig.driver);
    if (!homeStore.prepare())
        qCWarning(lcBoot) << "Home model will not persist:" << homeStore.lastError();

    services::HomeService home;
    home.setStore(&homeStore);
    if (!home.load(QStringLiteral(":/qt/qml/SmarTon/Resources/config/home-seed.json")))
        qCWarning(lcBoot) << "Could not load the home model:" << home.lastError();

    // THE HARDWARE BOUNDARY, and now there are two things that can sit at it.
    //
    // The loopback stands in for a radio SmarTon does not have - deliberately
    // with latency and optional packet loss, so the layers above are exercised
    // against the timing a real mesh has rather than against an instant,
    // always-successful fiction. It stays the default and stays in the tree:
    // it is what the tests run against, what a demo without a broker runs
    // against, and the only transport that can be told to fail on purpose.
    //
    // --transport mqtt://host swaps in the real one. NOT autodetected: a panel
    // that changes how it talks to the house because a broker happens to be
    // reachable is a panel whose behaviour depends on what else is on the
    // network. See ADR-0019, and ADR-0018 for where Matter joins the same seam.
    infrastructure::LoopbackDeviceTransport transport;
    bool usingBroker = false;
#ifdef ST_HAS_MQTT
    infrastructure::MqttDeviceTransport mqtt;
    const QUrl configuredBroker = brokerUrlFromEnvironment();
    const bool brokerFromEnvironment = !configuredBroker.isEmpty();
    if (brokerFromEnvironment || parser.isSet(brokerOption)) {
        const QUrl brokerUrl = brokerFromEnvironment
            ? configuredBroker : QUrl(parser.value(brokerOption));
        if (!brokerFromEnvironment && !brokerUrl.password().isEmpty()) {
            qCWarning(lcBoot) << "MQTT credentials in --transport are visible in process "
                                  "arguments; use /etc/smarton/smarton.env instead.";
        }
        // The ids to subscribe for. MQTT has no discovery that is common
        // across ecosystems, and a wildcard subscription would deliver every
        // topic on a shared broker.
        QStringList deviceIds;
        for (const domain::Device &device : home.devices())
            deviceIds.append(device.id);
        mqtt.setDeviceIds(deviceIds);
        const QString stateTopic = qEnvironmentVariable("SMARTON_MQTT_STATE_TOPIC");
        const QString commandTopic = qEnvironmentVariable("SMARTON_MQTT_COMMAND_TOPIC");
        if (!stateTopic.isEmpty())
            mqtt.setStateTopic(stateTopic);
        if (!commandTopic.isEmpty())
            mqtt.setCommandTopic(commandTopic);
        const QString onPayload = qEnvironmentVariable("SMARTON_MQTT_ON_PAYLOAD");
        const QString offPayload = qEnvironmentVariable("SMARTON_MQTT_OFF_PAYLOAD");
        if (!onPayload.isEmpty() && !offPayload.isEmpty())
            mqtt.setPayloads(onPayload, offPayload);
        if (mqtt.connectToBroker(brokerUrl)) {
            home.setTransport(&mqtt);
            usingBroker = true;
            qCInfo(lcBoot).noquote()
                << "Devices go through the MQTT broker at" << brokerUrl.toString()
                << "- until it answers, every device reads as unreachable.";
        } else {
            qCWarning(lcBoot).noquote()
                << "Ignoring --transport:" << mqtt.lastError();
        }
    }
#else
    if (parser.isSet(brokerOption) || !qEnvironmentVariableIsEmpty("SMARTON_MQTT_URL")) {
        // Said once and plainly. A flag that is silently ignored is how
        // somebody spends an afternoon wondering why their lamps do nothing.
        qCWarning(lcBoot) << "Ignoring --transport: this build has no Qt MQTT. "
                             "Reconfigure with Qt MQTT installed to use a broker.";
    }
#endif

    if (!usingBroker) {
        if (parser.isSet(transportOption))
            transport.setFailureRate(parser.value(transportOption).toDouble());
        for (const domain::Device &device : home.devices())
            transport.primeState(device.id, device.on);
        home.setTransport(&transport);
    }

    // ROLES ARE ENFORCED IN HomeService, and this is where it learns whose
    // hands are on the panel. HomeService starts at Viewer and refuses
    // everything, which is the right default for an authorisation check and
    // the wrong one for a running app - so it is set here for a session that
    // was already resumed above, and again on every sign-in and sign-out.
    //
    // The wiring is the composition root's rather than either service's: they
    // are siblings, and a HomeService that reaches into AuthService to ask who
    // is signed in is a HomeService that cannot be tested without one.
    const auto applyRole = [&home, &auth] {
        const std::optional<domain::User> user = auth.currentUser();
        home.setActor(user ? user->role() : domain::Role::Viewer);
    };
    applyRole();
    QObject::connect(&auth, &services::AuthService::signedIn,
                     &home, [applyRole](const QString &) { applyRole(); });
    QObject::connect(&auth, &services::AuthService::signedOut, &home, applyRole);

    // ---- the activity log ---------------------------------------------------
    // ASSEMBLED HERE, from signals that already existed. Nothing below this
    // line knows the log exists: HomeService announces every change it makes
    // and AuthService announces every sign-in, and connecting those to a
    // recorder is composition, which is this file's whole job.
    //
    // It is also the only place that CAN name an actor. HomeService knows the
    // signed-in role and AuthService knows the name; neither knows both.
    infrastructure::FileActivityStore activityStore;
    services::ActivityLog activity;
    activity.setStore(&activityStore);
    activity.load();
    qCInfo(lcBoot).noquote() << "Activity log:" << activityStore.fileName();

    const auto actorName = [&auth]() -> QString {
        const std::optional<domain::User> user = auth.currentUser();
        return user ? user->username() : QString();
    };

    QObject::connect(&home, &services::HomeService::deviceCommandRequested,
                     &activity, [&activity, actorName](const QString &, const QString &name,
                                                        bool on, services::HomeService::Actor actor) {
                         activity.record(QStringLiteral("command"), name,
                                         on ? QStringLiteral("on requested")
                                            : QStringLiteral("off requested"),
                                         actor == services::HomeService::Actor::User ? actorName() : QString());
                     });

    QObject::connect(&home, &services::HomeService::devicePowerChanged,
                     &activity, [&home, &activity](int index, bool on) {
                         const QList<domain::Device> devices = home.devices();
                         if (index < 0 || index >= devices.size())
                             return;
                         activity.record(QStringLiteral("device"),
                                         devices.at(index).name,
                                         on ? QStringLiteral("reported on")
                                            : QStringLiteral("reported off"));
                     });

    QObject::connect(&home, &services::HomeService::deviceCommandFailed,
                     &activity, [&activity, actorName](const QString &, const QString &name) {
                         activity.record(QStringLiteral("device"), name,
                                         QStringLiteral("command failed"), actorName());
                     });

    QObject::connect(&home, &services::HomeService::deviceSafetyTimeout,
                     &activity, [&activity](const QString &, const QString &name) {
                         activity.record(QStringLiteral("safety"), name,
                                         QStringLiteral("maximum run time reached; off requested"));
                     });

    QObject::connect(&home, &services::HomeService::deviceReachabilityChanged,
                     &activity, [&activity](const QString &, const QString &name, bool online) {
                         activity.record(QStringLiteral("device"), name,
                                         online ? QStringLiteral("came online")
                                                : QStringLiteral("went offline"));
                     });

    QObject::connect(&home, &services::HomeService::spacesChanged,
                     &activity, [&home, &activity, actorName] {
                         activity.record(QStringLiteral("space"),
                                         home.space().name,
                                         QStringLiteral("opened"), actorName());
                     });

    QObject::connect(&auth, &services::AuthService::signedIn,
                     &activity, [&activity](const QString &username) {
                         activity.record(QStringLiteral("session"), username,
                                         QStringLiteral("signed in"), username);
                     });
    QObject::connect(&auth, &services::AuthService::lockedForInactivity,
                     &activity, [&activity] {
                         activity.record(QStringLiteral("session"),
                                         QStringLiteral("Panel"),
                                         QStringLiteral("locked itself"));
                     });

    // Scenes now actually run. Without this they were a stored intention.
    services::SceneScheduler scheduler(home);
    if (!parser.isSet(noSchedulerOption))
        scheduler.start();

    // The scheduler's own signals rather than the devices it drives: one line
    // saying "Movie Night ran" is what a person wants, and six lines saying
    // six lamps changed is what they get if this listens further down.
    //
    // No actor, deliberately. The house did this to itself at eight o'clock,
    // and attributing it to whoever happened to be signed in would be a lie
    // in the one record people read to find out what happened.
    QObject::connect(&scheduler, &services::SceneScheduler::sceneActivated,
                     &activity, [&activity](const QString &, const QString &name) {
                         activity.record(QStringLiteral("scene"), name,
                                         QStringLiteral("ran"));
                     });
    QObject::connect(&scheduler, &services::SceneScheduler::sceneDeactivated,
                     &activity, [&activity](const QString &, const QString &name) {
                         activity.record(QStringLiteral("scene"), name,
                                         QStringLiteral("ended"));
                     });


    models::HomeViewModel homeViewModel;
    homeViewModel.setService(&home);
    // Members can be given a sign-in account, so the home view model needs
    // the auth service to create one and the avatar store to take custody of
    // their picture. Both optional: without them the Add-member form still
    // works and simply cannot offer a password or a photo.
    homeViewModel.setAuthService(&auth);
    homeViewModel.setAvatarStore(&avatars);

    QQmlApplicationEngine engine;

    // Appearance is a QML SINGLETON, so the engine constructs it and there is
    // no constructor to pass this to. Handed over BEFORE loadFromModule,
    // because the singleton is created on first use - which is Theme.qml, on
    // the very first frame - and a store arriving after that would mean the
    // accent read as default for one paint and then jumped.
    backend::Appearance::setPreferences(&preferences);

    // setInitialProperties, not setContextProperty: a context property is an
    // unqualified lookup, which .qmllint.ini treats as an error and which
    // defeats the QML compiler.
    const QSize startupSize = preferences.windowSize();
    models::ActivityListModel activityModel;
    activityModel.setLog(&activity);

    engine.setInitialProperties({
        { QStringLiteral("authViewModel"), QVariant::fromValue(&authViewModel) },
        { QStringLiteral("homeViewModel"), QVariant::fromValue(&homeViewModel) },
        { QStringLiteral("activityModel"), QVariant::fromValue(&activityModel) },
        { QStringLiteral("startupWidth"),  startupSize.width() },
        { QStringLiteral("startupHeight"), startupSize.height() },
        { QStringLiteral("startupSidebarWidth"), preferences.sidebarWidth() },
    });

#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("SmarTon.App", "Main");
#else
    // Qt 6.2 on the ThinClient RK3328 image predates loadFromModule() and
    // objectCreationFailed(). The QML module is still embedded at this
    // standard resource URL by qt_add_qml_module().
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated, &app,
        [](QObject *object, const QUrl &) {
            if (!object)
                QCoreApplication::exit(-1);
        }, Qt::QueuedConnection);
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/SmarTon/App/Main.qml")));
#endif

    // Remember the window size on the way out. Written here rather than on
    // every resize: a settings file rewritten on each drag frame is a lot of
    // flash wear for a value only read once, at startup.
    QObject::connect(&app, &QGuiApplication::aboutToQuit, &app, [&engine, &preferences] {
        const auto roots = engine.rootObjects();
        if (!roots.isEmpty()) {
            QObject *root = roots.first();
            if (auto *window = qobject_cast<QWindow *>(root))
                preferences.setWindowSize(window->size());

            // The rail's width, surfaced on the window by Main.qml. Read
            // through the property system rather than by reaching into the
            // scene: nothing here should know the shell's structure, and a
            // missing property is then a no-op rather than a crash.
            const QVariant sidebar = root->property("sidebarWidth");
            if (sidebar.isValid())
                preferences.setSidebarWidth(sidebar.toInt());
        }
        preferences.flush();
    });

    return app.exec();
}
