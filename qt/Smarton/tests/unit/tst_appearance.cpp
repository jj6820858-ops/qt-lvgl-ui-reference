#include <smarton/backend/theme/Appearance.h>
#include <smarton/backend/theme/DesignTokens.h>
#include <smarton/infrastructure/settings/QSettingsPreferences.h>

#include <QtCore/QSettings>
#include <QtCore/QTemporaryDir>
#include <QtCore/QVariantMap>
#include <QtTest/QSignalSpy>
#include <QtTest/QtTest>

#include <algorithm>
#include <cmath>
#include <memory>

using namespace smarton;

namespace {

/**
 * The reference implementation of the rule under test, written out longhand.
 *
 * Duplicating the formula rather than calling the production one is the point:
 * a test that asks the code to grade its own homework passes just as happily
 * when the coefficients are wrong. These numbers come from WCAG 2.1, not from
 * Appearance.cpp.
 */
double referenceContrast(const QColor &a, const QColor &b)
{
    const auto luminance = [](const QColor &c) {
        const auto channel = [](double v) {
            return v <= 0.03928 ? v / 12.92 : std::pow((v + 0.055) / 1.055, 2.4);
        };
        return 0.2126 * channel(c.redF())
             + 0.7152 * channel(c.greenF())
             + 0.0722 * channel(c.blueF());
    };
    const double la = luminance(a);
    const double lb = luminance(b);
    return (std::max(la, lb) + 0.05) / (std::min(la, lb) + 0.05);
}

} // namespace

class TestAppearance : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    void defaultsToTheBrandColour();
    void foregroundIsMeasuredNotGuessed();
    void defaultAccentKeepsTheDesignsForeground();
    void foregroundBeatsNaiveBrightness_data();
    void foregroundBeatsNaiveBrightness();
    void foregroundRuleCannotFailForAnyColour();
    void rejectsColoursThatVanishIntoThePage_data();
    void rejectsColoursThatVanishIntoThePage();
    void everyPresetPassesItsOwnRule();
    void forcesOpacity();
    void persistsAcrossConstruction();
    void resetClearsTheStoredValue();
    void garbageInSettingsFallsBackToDefault();
    void signalsOnlyOnRealChange();
    void hexTextEntry_data();
    void hexTextEntry();

private:
    QTemporaryDir m_dir;
    std::unique_ptr<infrastructure::QSettingsPreferences> m_prefs;

    QString settingsPath() const { return m_dir.filePath("prefs.ini"); }
};

void TestAppearance::init()
{
    // A real QSettings, on a real file, in a temp dir - never the developer's
    // own plist. The round-trip is half of what this class does, so faking the
    // store would leave the persistence untested.
    m_prefs = std::make_unique<infrastructure::QSettingsPreferences>(settingsPath());
    backend::Appearance::setPreferences(m_prefs.get());
}

void TestAppearance::cleanup()
{
    backend::Appearance::setPreferences(nullptr);
    m_prefs.reset();
}

void TestAppearance::defaultsToTheBrandColour()
{
    backend::Appearance appearance;
    QCOMPARE(appearance.accentColor(), backend::DesignTokens::primary());
    QVERIFY(appearance.usingDefaultAccent());
}

void TestAppearance::foregroundIsMeasuredNotGuessed()
{
    backend::Appearance appearance;
    appearance.setAccentColor(backend::DesignTokens::warning());   // pale amber
    const QColor fg = appearance.accentForeground();

    // Not "is it white" - whether white is right depends on the accent. The
    // claim being tested is that whatever comes back is the BETTER of the two
    // candidates, which is the only promise the API makes.
    const QColor other = fg == backend::DesignTokens::textPrimary()
                             ? backend::DesignTokens::surfaceDeep()
                             : backend::DesignTokens::textPrimary();
    QVERIFY(referenceContrast(fg, appearance.accentColor())
            >= referenceContrast(other, appearance.accentColor()));
}

/**
 * The default accent keeps the design's white, not the measured winner.
 *
 * Pinned as its own test because it is the one place the class deliberately
 * does NOT return the better-contrasting colour, and a future reader tidying
 * foregroundFor() down to readableOn() would otherwise only find out by
 * looking at a screenshot.
 */
void TestAppearance::defaultAccentKeepsTheDesignsForeground()
{
    backend::Appearance appearance;
    QCOMPARE(appearance.accentForeground(), backend::DesignTokens::primaryForeground());

    const QColor brand = backend::DesignTokens::primary();
    const QColor measured = backend::Appearance::readableOn(brand);

    // The deviation, stated as a number: near-black genuinely measures better
    // on the brand orange. If this stops being true - because the brand colour
    // changed - the exception has lost its reason to exist.
    QVERIFY(measured != backend::DesignTokens::primaryForeground());
    QVERIFY(referenceContrast(measured, brand)
            > referenceContrast(backend::DesignTokens::primaryForeground(), brand));
    QVERIFY(referenceContrast(backend::DesignTokens::primaryForeground(), brand) >= 3.0);
}

void TestAppearance::foregroundBeatsNaiveBrightness_data()
{
    QTest::addColumn<QColor>("accent");
    QTest::addColumn<bool>("expectLightText");

    // The four colours that break a qGray()/HSV-value threshold. Pure blue is
    // dark to the eye and mid-grey to qGray(); pure yellow is the reverse.
    QTest::newRow("pure blue")   << QColor(0x00, 0x00, 0xFF) << true;
    QTest::newRow("pure yellow") << QColor(0xFF, 0xFF, 0x00) << false;
    QTest::newRow("pure green")  << QColor(0x00, 0xFF, 0x00) << false;
    QTest::newRow("pure red")    << QColor(0xFF, 0x00, 0x00) << false;
}

void TestAppearance::foregroundBeatsNaiveBrightness()
{
    QFETCH(QColor, accent);
    QFETCH(bool, expectLightText);

    const QColor fg = backend::Appearance::readableOn(accent);
    QCOMPARE(fg == backend::DesignTokens::textPrimary(), expectLightText);

    // qGray() ranks all four within 40 points of each other, so a threshold on
    // it would have to answer at least one of them wrongly. Stated as an
    // assertion so the row that would regress says why it matters.
    QVERIFY(referenceContrast(fg, accent) >= referenceContrast(
                expectLightText ? backend::DesignTokens::surfaceDeep()
                                : backend::DesignTokens::textPrimary(),
                accent));
}

/**
 * The foreground clause of isAcceptableAccent() cannot fail. Asserted over the
 * whole RGB cube rather than assumed.
 *
 * Because the two candidates are white and #101113 - a near-black, luminance
 * 0.0056 - they span almost the entire range, and the worst any colour can do
 * against the BETTER of them is about 4.35:1 (at roughly #248C0C). So the
 * clause never rejects anything a user can type; the background clause is the
 * one that does the work.
 *
 * The check stays in the production code anyway, and this test is why it can:
 * it guards the INVARIANT, not the input. If surfaceDeep is ever lightened
 * toward a mid tone, the candidate pair stops spanning the range, real colours
 * start failing, and this test fails first - which is the warning that the
 * accent picker has quietly become able to produce an unreadable button.
 */
void TestAppearance::foregroundRuleCannotFailForAnyColour()
{
    double worst = 100.0;
    QColor worstColour;

    // Step 8: 32,768 samples, well under a second, and fine enough that no
    // pocket of the cube is missed - contrast varies smoothly in RGB.
    for (int r = 0; r < 256; r += 8) {
        for (int g = 0; g < 256; g += 8) {
            for (int b = 0; b < 256; b += 8) {
                const QColor candidate(r, g, b);
                const double best = referenceContrast(
                    backend::Appearance::readableOn(candidate), candidate);
                if (best < worst) {
                    worst = best;
                    worstColour = candidate;
                }
            }
        }
    }

    QVERIFY2(worst >= 3.0,
             qPrintable(QStringLiteral("%1 leaves only %2:1 for its best foreground")
                            .arg(worstColour.name()).arg(worst, 0, 'f', 2)));
}

void TestAppearance::rejectsColoursThatVanishIntoThePage_data()
{
    QTest::addColumn<QColor>("candidate");
    QTest::addColumn<bool>("acceptable");

    QTest::newRow("brand default")  << backend::DesignTokens::primary()    << true;
    QTest::newRow("design amber")   << backend::DesignTokens::warning()    << true;
    // 3.48:1 against the page. It LOOKS like a bad accent and is a legal one -
    // recorded so nobody "fixes" the rule by eye and silently tightens it.
    QTest::newRow("mid grey")       << QColor(0x76, 0x76, 0x76)            << true;
    // 1.84:1. Perfectly readable white-on-blue, and almost invisible as a
    // border on #202326 - the case the second clause exists for.
    QTest::newRow("pure blue")      << QColor(0x00, 0x00, 0xFF)            << false;
    // 1.05:1 - the page colour with a nudge.
    QTest::newRow("near-page dark") << QColor(0x24, 0x27, 0x2A)            << false;
    // 2.26:1: the design's own accentViolet, which is why the preset list
    // offers accentVioletSoft instead.
    QTest::newRow("design violet")  << backend::DesignTokens::accentViolet() << false;
    QTest::newRow("invalid")        << QColor()                           << false;
}

void TestAppearance::rejectsColoursThatVanishIntoThePage()
{
    QFETCH(QColor, candidate);
    QFETCH(bool, acceptable);

    QCOMPARE(backend::Appearance::isAcceptableAccent(candidate), acceptable);

    backend::Appearance appearance;
    appearance.setAccentColor(candidate);
    // Refusal must leave the previous accent standing, not fall through to
    // something else: a rejected choice that blanks the UI is worse than the
    // bad colour would have been.
    QCOMPARE(appearance.accentColor() == candidate, acceptable);
}

void TestAppearance::everyPresetPassesItsOwnRule()
{
    backend::Appearance appearance;
    const QVariantList presets = appearance.accentPresets();
    QVERIFY(!presets.isEmpty());

    for (const QVariant &entry : presets) {
        const QVariantMap preset = entry.toMap();
        const QColor colour = preset.value(QStringLiteral("color")).value<QColor>();
        const QString name  = preset.value(QStringLiteral("name")).toString();

        // Offering a swatch the setter then refuses is the worst outcome
        // available: the user clicks, nothing happens, and there is nothing
        // on screen to explain it.
        QVERIFY2(backend::Appearance::isAcceptableAccent(colour),
                 qPrintable(QStringLiteral("preset %1 (%2) fails its own rule")
                                .arg(name, colour.name())));

        appearance.setAccentColor(colour);
        QCOMPARE(appearance.accentColor(), colour);

        QCOMPARE(preset.value(QStringLiteral("foreground")).value<QColor>(),
                 backend::Appearance::foregroundFor(colour));
    }
}

void TestAppearance::forcesOpacity()
{
    backend::Appearance appearance;
    appearance.setAccentColor(QColor(0x31, 0xAA, 0x7A, 0x40));
    QCOMPARE(appearance.accentColor().alpha(), 255);
    QCOMPARE(appearance.accentColor().rgb(), QColor(0x31, 0xAA, 0x7A).rgb());
}

void TestAppearance::persistsAcrossConstruction()
{
    const QColor chosen = backend::DesignTokens::success();
    {
        backend::Appearance appearance;
        appearance.setAccentColor(chosen);
    }
    m_prefs->flush();

    // A SECOND QSettings on the same file, not the same object re-read: the
    // claim is that the choice survives the process, and an in-memory cache
    // would satisfy the weaker version of this test.
    infrastructure::QSettingsPreferences reopened(settingsPath());
    backend::Appearance::setPreferences(&reopened);

    backend::Appearance restored;
    QCOMPARE(restored.accentColor(), chosen);
    QVERIFY(!restored.usingDefaultAccent());
}

void TestAppearance::resetClearsTheStoredValue()
{
    {
        backend::Appearance appearance;
        appearance.setAccentColor(backend::DesignTokens::info());
        appearance.resetAccentColor();
        QVERIFY(appearance.usingDefaultAccent());
    }
    m_prefs->flush();

    // Absent, not "the default written out": the file has to keep "never
    // chose" distinguishable from "chose the default".
    QCOMPARE(m_prefs->accentColor(), QString());
}

void TestAppearance::garbageInSettingsFallsBackToDefault()
{
    {
        QSettings raw(settingsPath(), QSettings::IniFormat);
        raw.setValue(QStringLiteral("ui/accent"), QStringLiteral("blueish"));
        raw.sync();
    }

    infrastructure::QSettingsPreferences reopened(settingsPath());
    QCOMPARE(reopened.accentColor(), QString());

    backend::Appearance::setPreferences(&reopened);
    backend::Appearance appearance;
    QCOMPARE(appearance.accentColor(), backend::DesignTokens::primary());
}

void TestAppearance::signalsOnlyOnRealChange()
{
    backend::Appearance appearance;
    QSignalSpy spy(&appearance, &backend::Appearance::accentColorChanged);

    appearance.setAccentColor(backend::DesignTokens::info());
    QCOMPARE(spy.count(), 1);

    appearance.setAccentColor(backend::DesignTokens::info());   // same value
    QCOMPARE(spy.count(), 1);

    appearance.setAccentColor(QColor(0x00, 0x00, 0xFF));        // refused
    QCOMPARE(spy.count(), 1);

    appearance.resetAccentColor();
    QCOMPARE(spy.count(), 2);

    appearance.resetAccentColor();                              // already default
    QCOMPARE(spy.count(), 2);
}

void TestAppearance::hexTextEntry_data()
{
    QTest::addColumn<QString>("typed");
    QTest::addColumn<bool>("accepted");

    QTest::newRow("full hex")     << QStringLiteral("#31AA7A") << true;
    QTest::newRow("named colour") << QStringLiteral("tomato")  << true;
    QTest::newRow("no hash")      << QStringLiteral("31AA7A")  << false;
    // 3-digit hex is legal CSS-style shorthand and QColor parses it, so the
    // field must judge it on contrast like any other colour rather than on
    // length. #FA0 -> #FFAA00 passes; #31A -> #3311AA is 1.35:1 on the page.
    QTest::newRow("short hex ok") << QStringLiteral("#FA0")    << true;
    QTest::newRow("short hex dim")<< QStringLiteral("#31A")    << false;
    // Every other prefix of a hex someone is halfway through typing. None of
    // these may warn or throw - they are the normal state of the field.
    QTest::newRow("two chars")    << QStringLiteral("#3")      << false;
    QTest::newRow("empty")        << QString()                 << false;
    QTest::newRow("nonsense")     << QStringLiteral("blueish") << false;
    QTest::newRow("legal, dark")  << QStringLiteral("#000000") << false; // vanishes into the page
}

void TestAppearance::hexTextEntry()
{
    QFETCH(QString, typed);
    QFETCH(bool, accepted);

    QCOMPARE(backend::Appearance::isAcceptableAccentName(typed), accepted);

    backend::Appearance appearance;
    const QColor before = appearance.accentColor();
    appearance.setAccentColorName(typed);
    QCOMPARE(appearance.accentColor() != before, accepted);
}

QTEST_GUILESS_MAIN(TestAppearance)
#include "tst_appearance.moc"
