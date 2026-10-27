#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtQml/qqml.h>
#include <QtQml/qqmlprivate.h>
#include <QtQml/qqmlregistration.h>

namespace smarton::backend {

/**
 * @brief Resolves the UI font family at startup, once.
 *
 * WHY THIS EXISTS. The theme used to hard-code `"Segoe UI"`. That family
 * ships only on Windows. On macOS Qt silently substituted something else; on
 * the panel's minimal Yocto rootfs it would substitute whatever happened to be
 * installed, or nothing suitable. Every metric in design/README.md was
 * measured against a specific typeface, so a substitution makes the type the
 * wrong width and weight and elides labels the design does not elide — and it
 * does so silently, which is why it survived this long.
 *
 * Resolution order:
 *  1. Any font file bundled under resources/fonts/ is registered first, and
 *     the families it provides win. On the panel this is the only correct
 *     answer, because nothing else is guaranteed to be installed.
 *  2. Failing that, the first family from a preference list that the system
 *     actually reports — checked against QFontDatabase, not assumed.
 *  3. Failing that, whatever Qt considers the default sans-serif.
 *
 * The resolved family and how it was chosen are logged at startup, so a
 * substitution on a target is visible in the boot log instead of being
 * discovered from a screenshot.
 */
class Typography : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    /*! The family every StLabel uses. Resolved once, at construction. */
    Q_PROPERTY(QString family READ family CONSTANT)
    /*! True when the family came from a bundled file rather than the system. */
    Q_PROPERTY(bool bundled READ isBundled CONSTANT)

public:
    explicit Typography(QObject *parent = nullptr);

    [[nodiscard]] QString family() const { return m_family; }
    [[nodiscard]] bool isBundled() const { return m_bundled; }

    /**
     * Register every font under \a resourceDir and return the families added.
     * Called by the constructor; exposed so tests can point it elsewhere.
     */
    static QStringList registerBundledFonts(const QString &resourceDir);

    /** First family of @p candidates that the system actually has. */
    [[nodiscard]] static QString firstAvailable(const QStringList &candidates);

private:
    QString m_family;
    bool    m_bundled = false;
};

} // namespace smarton::backend
