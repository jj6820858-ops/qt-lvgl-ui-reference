#include <smarton/backend/theme/Typography.h>

#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QFileInfoList>
#include <QtCore/QLoggingCategory>
#include <QtGui/QFont>
#include <QtGui/QFontDatabase>

namespace smarton::backend {

namespace {

Q_LOGGING_CATEGORY(lcType, "smarton.typography")

constexpr auto kBundledFontDir = ":/qt/qml/SmarTon/Resources/fonts";

/**
 * Fallbacks, best first, for when nothing is bundled.
 *
 * Deliberately platform-agnostic and checked at runtime rather than chosen by
 * #ifdef: a developer machine, a CI container and the panel all report
 * different sets, and an #ifdef would only encode what was true on whichever
 * machine wrote it. Inter and Roboto first because their metrics are closest
 * to the Figma; DejaVu because it is what a bare Yocto image usually has.
 */
const QStringList &preferredFamilies()
{
    static const QStringList families {
        QStringLiteral("Inter"),
        QStringLiteral("Roboto"),
        QStringLiteral("Noto Sans"),
        QStringLiteral("Source Sans 3"),
        QStringLiteral("Open Sans"),
        QStringLiteral("Segoe UI"),          // Windows
        QStringLiteral("Helvetica Neue"),    // macOS
        QStringLiteral("DejaVu Sans"),       // typical embedded Linux
        QStringLiteral("Liberation Sans"),
    };
    return families;
}

} // namespace

Typography::Typography(QObject *parent)
    : QObject(parent)
{
    const QStringList bundled = registerBundledFonts(QLatin1String(kBundledFontDir));
    if (!bundled.isEmpty()) {
        m_family = bundled.first();
        m_bundled = true;
        qCInfo(lcType) << "Using bundled font family:" << m_family;
        return;
    }

    m_family = firstAvailable(preferredFamilies());
    if (!m_family.isEmpty()) {
        qCWarning(lcType).noquote()
            << QStringLiteral("No font bundled under %1; falling back to the system "
                              "family '%2'. Metrics in design/README.md were measured "
                              "against a bundled face - bundle one before shipping.")
                   .arg(QLatin1String(kBundledFontDir), m_family);
        return;
    }

    m_family = QFont().defaultFamily();
    qCCritical(lcType) << "None of the preferred families is installed. Falling back to"
                       << m_family << "- the UI will not match the design.";
}

QStringList Typography::registerBundledFonts(const QString &resourceDir)
{
    QStringList families;

    const QDir dir(resourceDir);
    if (!dir.exists())
        return families;

    const QStringList filters { QStringLiteral("*.ttf"), QStringLiteral("*.otf") };
    const QFileInfoList entries = dir.entryInfoList(filters, QDir::Files, QDir::Name);

    for (const QFileInfo &entry : entries) {
        const int id = QFontDatabase::addApplicationFont(entry.absoluteFilePath());
        if (id < 0) {
            qCWarning(lcType) << "Could not register font" << entry.fileName();
            continue;
        }
        // A variable or multi-weight file reports several families; take them
        // all, and keep the first for the theme.
        families += QFontDatabase::applicationFontFamilies(id);
    }

    families.removeDuplicates();
    return families;
}

QString Typography::firstAvailable(const QStringList &candidates)
{
    const QStringList installed = QFontDatabase::families();
    for (const QString &candidate : candidates) {
        if (installed.contains(candidate, Qt::CaseInsensitive))
            return candidate;
    }
    return {};
}

} // namespace smarton::backend
