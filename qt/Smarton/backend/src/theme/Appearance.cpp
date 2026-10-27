#include <smarton/backend/theme/Appearance.h>

#include <smarton/backend/theme/DesignTokens.h>
#include <smarton/services/IPreferences.h>

#include <QtCore/QList>
#include <QtCore/QPair>
#include <QtCore/QVariantMap>
#include <QtGui/QGuiApplication>

#include <algorithm>
#include <cmath>

namespace smarton::backend {

namespace {

services::IPreferences *g_preferences = nullptr;

/**
 * WCAG relative luminance.
 *
 * Not `qGray()` and not `value()` from HSV, both of which are tempting and
 * both of which are wrong: they treat the channels as equally bright, so pure
 * blue reads as mid-grey and gets white text it cannot carry, while yellow
 * reads the same and gets white text on a near-white background. The
 * coefficients below are the ones the eye actually uses.
 */
qreal relativeLuminance(const QColor &c)
{
    const auto linear = [](qreal channel) {
        return channel <= 0.03928 ? channel / 12.92
                                  : std::pow((channel + 0.055) / 1.055, 2.4);
    };
    return 0.2126 * linear(c.redF())
         + 0.7152 * linear(c.greenF())
         + 0.0722 * linear(c.blueF());
}

qreal contrastRatio(const QColor &a, const QColor &b)
{
    const qreal la = relativeLuminance(a);
    const qreal lb = relativeLuminance(b);
    return (std::max(la, lb) + 0.05) / (std::min(la, lb) + 0.05);
}

/**
 * WCAG 1.4.11: the floor for a UI component that has to be SEEN rather than
 * read - a border, a slider fill, the underline on a tab.
 *
 * Measured against the page background rather than against every surface in
 * the theme, and that limit is deliberate. On surfaceRaised (#40464D) the
 * brand orange itself only reaches 2.49:1, so a rule that demanded 3:1
 * everywhere would reject the design's own accent - which would say the rule
 * is wrong, not the colour. The page background is where accent strokes and
 * accent text actually sit on these screens.
 */
constexpr qreal kMinContrast = 3.0;

} // namespace

Appearance::Appearance(QObject *parent)
    : QObject(parent)
    , m_accent(DesignTokens::primary())
{
    // Detected first, so a machine that has never been configured still gets
    // an answer suited to it rather than the most expensive one.
    m_renderTier = detectRenderTier();

    if (!g_preferences)
        return;

    const QColor stored(g_preferences->accentColor());
    // A settings file is hand-editable, so a stored value is a suggestion.
    if (stored.isValid())
        m_accent = stored;

    const QString theme = g_preferences->themeName();
    if (theme == QLatin1String("glass") || theme == QLatin1String("figma"))
        m_theme = theme;

    // -1 is the stored "never chosen", which leaves the detection standing.
    const int tier = g_preferences->renderTier();
    if (tier >= 0)
        m_renderTier = qBound(0, tier, 2);

    // Shadows default on and follow the tier only when nothing has been
    // chosen: a tier-0 machine has no business drawing a blur pass per tile,
    // and a machine whose operator has said "shadows on" should keep them.
    m_shadows = g_preferences->shadowsEnabled() && m_renderTier > 0;
}

void Appearance::setPreferences(services::IPreferences *preferences)
{
    // A free function over a file-static, because a QML singleton is
    // constructed by the engine and there is no constructor to pass this to.
    // The composition root calls it before the engine loads; without it the
    // class still works and simply forgets every choice on exit.
    g_preferences = preferences;
}

void Appearance::setThemeName(const QString &name)
{
    // Two legal values. An unknown one falls back rather than being stored,
    // so a hand-edited settings file cannot leave the app with no theme.
    const QString next = name == QLatin1String("glass") ? name
                                                        : QStringLiteral("figma");
    if (next == m_theme)
        return;

    m_theme = next;
    if (g_preferences)
        g_preferences->setThemeName(m_theme);
    emit themeChanged();
}

void Appearance::setRenderTier(int tier)
{
    const int next = qBound(0, tier, 2);
    if (next == m_renderTier)
        return;

    m_renderTier = next;
    if (g_preferences)
        g_preferences->setRenderTier(m_renderTier);
    emit renderTierChanged();
}

void Appearance::setShadowsEnabled(bool enabled)
{
    if (enabled == m_shadows)
        return;

    m_shadows = enabled;
    if (g_preferences)
        g_preferences->setShadowsEnabled(m_shadows);
    emit shadowsEnabledChanged();
}

int Appearance::detectRenderTier()
{
    // THE PLATFORM PLUGIN, not the GPU.
    //
    // The obvious approach - make a GL context, read GL_RENDERER, match the
    // slow families - is wrong twice over on Qt 6. The scene graph runs on the
    // RHI, so on macOS it is Metal and on Windows D3D11; a GL renderer string
    // would describe a backend the app never uses. And creating a throwaway GL
    // context on a Metal application to ask a question about Metal is a cost
    // paid for a wrong answer.
    //
    // What IS answerable is which platform plugin is running. eglfs and
    // linuxfb mean the application owns the framebuffer with no compositor
    // above it, which in practice means an embedded board - the RK3328 case
    // this tiering exists for. A desktop plugin means a desktop GPU.
    //
    // Coarse, and deliberately so: it is a DEFAULT, overridable in settings
    // and with --render-tier, and it is wrong in the safe direction. An
    // unrecognised platform gets the good-looking path; the panel does not.
    const QString platform = QGuiApplication::platformName().toLower();

    static const QStringList directToFramebuffer {
        QStringLiteral("eglfs"), QStringLiteral("linuxfb"),
        QStringLiteral("directfb"), QStringLiteral("kms"),
        QStringLiteral("vnc"),
    };
    for (const QString &name : directToFramebuffer) {
        if (platform.contains(name))
            return 1;
    }

    // Offscreen and minimal are test and CI runs. Nothing is looked at, so
    // nothing should be spent making it pretty.
    if (platform.contains(QLatin1String("offscreen"))
        || platform.contains(QLatin1String("minimal")))
        return 0;

    return 2;
}

QColor Appearance::readableOn(const QColor &background)
{
    // Both candidates are measured rather than assumed from a luminance
    // threshold: a mid-tone accent can fail BOTH at 4.5:1, and picking the
    // better of the two is the only honest answer available without changing
    // the colour the user asked for.
    const QColor light = DesignTokens::textPrimary();      // #FFFFFF
    const QColor dark  = DesignTokens::surfaceDeep();      // #101113
    return contrastRatio(light, background) >= contrastRatio(dark, background)
               ? light : dark;
}

QColor Appearance::foregroundFor(const QColor &accent)
{
    // The one exception, and the reason it is one is in
    // DesignTokens::primaryForeground(): at the default accent the design's
    // answer wins over the measured one, so adding a picker does not quietly
    // restyle every primary button in the app.
    return accent == DesignTokens::primary() ? DesignTokens::primaryForeground()
                                             : readableOn(accent);
}

QColor Appearance::accentForeground() const
{
    return foregroundFor(m_accent);
}

bool Appearance::usingDefaultAccent() const
{
    return m_accent == DesignTokens::primary();
}

QVariantList Appearance::accentPresets() const
{
    // Drawn from the design's own palette, so every choice already belongs to
    // the theme. Offering a free colour wheel as the primary affordance is how
    // an app ends up with a lime-green panel in someone's hallway.
    const QList<QPair<QString, QColor>> presets {
        { tr("Ember"),     DesignTokens::primary() },        // the brand default
        { tr("Signal"),    DesignTokens::info() },
        { tr("Meadow"),    DesignTokens::success() },
        { tr("Amber"),     DesignTokens::warning() },
        { tr("Orchid"),    DesignTokens::accentVioletSoft() },
        { tr("Rose"),      DesignTokens::danger() },
        { tr("Sky"),       DesignTokens::infoSoft() },
        { tr("Mint"),      DesignTokens::successSoft() },
    };

    QVariantList out;
    out.reserve(presets.size());
    for (const auto &[name, colour] : presets) {
        out.append(QVariantMap {
            { QStringLiteral("name"),       name },
            { QStringLiteral("color"),      colour },
            { QStringLiteral("foreground"), foregroundFor(colour) },
        });
    }
    return out;
}

bool Appearance::isAcceptableAccent(const QColor &color)
{
    if (!color.isValid())
        return false;

    QColor opaque = color;
    opaque.setAlpha(255);

    // TWO tests, because the accent does two jobs: it is a FILL that text sits
    // on, and it is a MARK - a border, an underline - seen against the page.
    //
    // Only the second one currently rejects anything, and that is worth being
    // explicit about rather than leaving as an accident. Because the two
    // foreground candidates are white and a near-black #101113, they span
    // almost the whole luminance range, so every colour in the RGB cube clears
    // 4.3:1 against one of them - measured over the cube in tst_appearance.
    // The first test therefore guards the INVARIANT, not the input: if
    // surfaceDeep is ever lightened toward a mid tone the candidates stop
    // spanning the range, real colours begin to fail, and the guard is already
    // in place. The test fails first and says so.
    return contrastRatio(readableOn(opaque), opaque) >= kMinContrast
        && contrastRatio(opaque, DesignTokens::background()) >= kMinContrast;
}

bool Appearance::isAcceptableAccentName(const QString &name)
{
    return QColor(name).isValid() && isAcceptableAccent(QColor(name));
}

void Appearance::setAccentColorName(const QString &name)
{
    if (QColor(name).isValid())
        setAccentColor(QColor(name));
}

void Appearance::setAccentColor(const QColor &color)
{
    if (!color.isValid() || color == m_accent)
        return;

    // Opaque: a translucent accent would let the surface behind it change what
    // the button looks like from screen to screen.
    QColor opaque = color;
    opaque.setAlpha(255);

    if (!isAcceptableAccent(opaque))
        return;

    m_accent = opaque;
    if (g_preferences)
        g_preferences->setAccentColor(opaque.name(QColor::HexRgb));
    emit accentColorChanged();
}

void Appearance::resetAccentColor()
{
    if (usingDefaultAccent())
        return;
    m_accent = DesignTokens::primary();
    if (g_preferences)
        g_preferences->setAccentColor(QString());
    emit accentColorChanged();
}

} // namespace smarton::backend
