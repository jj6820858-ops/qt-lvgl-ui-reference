#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QVariantList>
#include <QtGui/QColor>
#include <QtQml/qqml.h>
#include <QtQml/qqmlprivate.h>
#include <QtQml/qqmlregistration.h>

namespace smarton::services { class IPreferences; }

namespace smarton::backend {

/**
 * @brief The one value in the design a user is allowed to change.
 *
 * WHY SEPARATE FROM DesignTokens. `DesignTokens` is the Figma file in C++ -
 * every value verbatim, all CONSTANT, and it is worth keeping that way: it is
 * the reference the built UI is checked against. An accent the user picked is
 * not a design token, it is a preference that happens to override one. Mixing
 * them would mean the file that documents the design no longer describes what
 * is on screen.
 *
 * So `DesignTokens::primary` remains the brand orange and the default, and
 * this holds the override. `Theme.primary` reads from here.
 *
 * WHY ONLY THE ACCENT. Surfaces, text and state colours are a system: the
 * contrast ratios between them were designed together, and letting someone
 * set the page background is how an app becomes unreadable. The accent is the
 * one colour that carries no information beyond "this is actionable", so it
 * can move without breaking anything - provided what sits ON it moves too,
 * which is what \l accentForeground is for.
 *
 * PREFERENCES ARE INJECTED STATICALLY. A QML singleton is constructed by the
 * engine, which cannot pass constructor arguments, so the composition root
 * calls setPreferences() before the engine loads. Without it the class still
 * works - it just forgets the choice on exit.
 */
class Appearance : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    /*! The user's accent, or the brand orange when they have not chosen. */
    Q_PROPERTY(QColor accentColor READ accentColor NOTIFY accentColorChanged)
    /*! Text and icons drawn ON the accent. Derived, never chosen: see the
        implementation for why picking it by hand is a contrast bug waiting. */
    Q_PROPERTY(QColor accentForeground READ accentForeground NOTIFY accentColorChanged)
    Q_PROPERTY(bool usingDefaultAccent READ usingDefaultAccent NOTIFY accentColorChanged)
    /*! [{ name, color }, ...] - the offered swatches. */
    Q_PROPERTY(QVariantList accentPresets READ accentPresets CONSTANT)

    /*!
        "figma" or "glass".

        TWO THEMES, NOT A REPLACEMENT. The measured Figma treatment stays the
        default and the reference - design/measurements.md checks the build
        against it, and ADR-0008's reflow argument rests on it. The glass
        theme is a second skin over the SAME tokens, which is also the only
        real proof that the token layer works: a design system nobody has ever
        re-skinned is a design system nobody has tested.
    */
    Q_PROPERTY(QString themeName READ themeName WRITE setThemeName NOTIFY themeChanged)
    Q_PROPERTY(bool glassTheme READ glassTheme NOTIFY themeChanged)

    /*!
        How much per-frame GPU work this machine can afford: 0 plain, 1
        gradients and glow, 2 full glass with backdrop blur and particles.

        A REAL constraint, not a preference. Backdrop blur is a full-screen
        read-modify-write per blurred surface and particles are per-frame
        geometry churn; on the RK3328's Mali-450 - no compute shaders, shared
        memory bandwidth - that is the difference between 60fps and single
        digits. Tiering means the glass theme is honest on both machines
        instead of unusable on one.
    */
    Q_PROPERTY(int renderTier READ renderTier WRITE setRenderTier NOTIFY renderTierChanged)
    /*!
        Drop shadows under the tiles.

        Separate from \l renderTier, and not folded into it, because it is a
        different cost with a different answer. A tier is about blur and
        particles - decoration you lose nothing by dropping. A shadow is drawn
        with MultiEffect, which is a GPU blur pass PER elevated item, and a
        dashboard has a dozen of them: on the panel's Mali GPU that is the
        single largest thing on the frame budget, and it is worth being able
        to turn off while keeping the glass theme's gradients.

        It has been in IPreferences since the settings layer was written and
        nothing read it - Theme returned a hard-coded true. This is where it
        finally arrives.
    */
    Q_PROPERTY(bool shadowsEnabled READ shadowsEnabled WRITE setShadowsEnabled
               NOTIFY shadowsEnabledChanged)
    Q_PROPERTY(bool blurEnabled READ blurEnabled NOTIFY renderTierChanged)
    Q_PROPERTY(bool particlesEnabled READ particlesEnabled NOTIFY renderTierChanged)

public:
    explicit Appearance(QObject *parent = nullptr);

    /** Called by the composition root before the QML engine loads. */
    static void setPreferences(services::IPreferences *preferences);

    [[nodiscard]] QColor accentColor() const { return m_accent; }
    [[nodiscard]] QColor accentForeground() const;
    [[nodiscard]] bool usingDefaultAccent() const;
    [[nodiscard]] QVariantList accentPresets() const;

    /**
     * Would \a color be accepted? Exposed so the picker can say NO BEFORE the
     * user commits, and say why - a setter that silently ignores bad input is
     * indistinguishable from a broken one.
     */
    Q_INVOKABLE static bool isAcceptableAccent(const QColor &color);

    /** Ignores anything isAcceptableAccent() rejects. */
    Q_INVOKABLE void setAccentColor(const QColor &color);

    /**
     * The same two, taking the raw text of a hex field.
     *
     * Separate entry points rather than relying on QML's string-to-color
     * coercion: handed "#GG0000" that coercion warns on the console and yields
     * an invalid colour, so a half-typed hex would spray warnings on every
     * keystroke. Parsing here makes "not a colour yet" an ordinary false.
     */
    Q_INVOKABLE static bool isAcceptableAccentName(const QString &name);
    Q_INVOKABLE void setAccentColorName(const QString &name);
    Q_INVOKABLE void resetAccentColor();

    /**
     * Black or white, whichever is readable on @p background.
     *
     * Exposed because the same question comes up for any coloured surface -
     * a preset swatch has to label itself, and a chip tinted with the accent
     * has to know what to draw on it.
     */
    Q_INVOKABLE static QColor readableOn(const QColor &background);

    /**
     * The foreground SmarTon actually uses for an accent.
     *
     * readableOn() with one documented exception: at the design's own accent
     * the design's own white wins, even though near-black measures better.
     * See DesignTokens::primaryForeground().
     */
    Q_INVOKABLE static QColor foregroundFor(const QColor &accent);

    [[nodiscard]] QString themeName() const { return m_theme; }
    [[nodiscard]] bool glassTheme() const { return m_theme == QLatin1String("glass"); }
    Q_INVOKABLE void setThemeName(const QString &name);

    [[nodiscard]] int renderTier() const { return m_renderTier; }
    Q_INVOKABLE void setRenderTier(int tier);
    [[nodiscard]] bool shadowsEnabled() const { return m_shadows; }
    Q_INVOKABLE void setShadowsEnabled(bool enabled);
    [[nodiscard]] bool blurEnabled() const { return m_renderTier >= 2; }
    [[nodiscard]] bool particlesEnabled() const { return m_renderTier >= 2; }

    /*!
        Best guess at what this machine can afford, from the platform plugin.

        A GUESS, and named like one - see the implementation for why the
        platform plugin is a better signal than the GPU's own name on Qt 6.
        Wrong in the safe direction: an unrecognised platform gets the
        good-looking path, and the answer is overridable in settings and with
        --render-tier.
    */
    static int detectRenderTier();

signals:
    void accentColorChanged();
    void themeChanged();
    void renderTierChanged();
    void shadowsEnabledChanged();

private:
    QColor  m_accent;
    QString m_theme = QStringLiteral("figma");
    int     m_renderTier = 2;
    bool    m_shadows = true;
};

} // namespace smarton::backend
