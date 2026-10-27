#include <QtTest>

#include <smarton/domain/entities/Reading.h>

using namespace smarton;
using domain::Range;
using domain::Reading;

class TestReading : public QObject
{
    Q_OBJECT
private slots:
    void clamps_data();
    void clamps();
    void normalises_data();
    void normalises();
    void severityThresholds_data();
    void severityThresholds();
    void degenerateRangeIsSafe();
    void equalityComparesEveryField();
    void benchmarkClamp();
};

void TestReading::clamps_data()
{
    QTest::addColumn<double>("input");
    QTest::addColumn<double>("expected");
    QTest::newRow("below minimum") << -50.0 << 0.0;
    QTest::newRow("at minimum") << 0.0 << 0.0;
    QTest::newRow("inside") << 24.0 << 24.0;
    QTest::newRow("at maximum") << 60.0 << 60.0;
    QTest::newRow("above maximum") << 900.0 << 60.0;
}

void TestReading::clamps()
{
    QFETCH(double, input);
    QFETCH(double, expected);
    Reading r(QStringLiteral("Pressure"), QStringLiteral("cmH2O"), input, Range { 0.0, 60.0 });
    QCOMPARE(r.value(), expected);
}

void TestReading::normalises_data()
{
    QTest::addColumn<double>("input");
    QTest::addColumn<double>("expected");
    QTest::newRow("zero") << 0.0 << 0.0;
    QTest::newRow("half") << 30.0 << 0.5;
    QTest::newRow("full") << 60.0 << 1.0;
}

void TestReading::normalises()
{
    QFETCH(double, input);
    QFETCH(double, expected);
    Reading r(QStringLiteral("Pressure"), QStringLiteral("cmH2O"), input, Range { 0.0, 60.0 });
    QVERIFY(qAbs(r.progress() - expected) < 0.0001);
}

void TestReading::severityThresholds_data()
{
    QTest::addColumn<double>("value");
    QTest::addColumn<int>("expected");
    QTest::newRow("low") << 10.0 << int(common::Severity::Normal);
    QTest::newRow("just below 75%") << 74.0 << int(common::Severity::Normal);
    QTest::newRow("at 75%") << 75.0 << int(common::Severity::Warning);
    QTest::newRow("just below 90%") << 89.0 << int(common::Severity::Warning);
    QTest::newRow("at 90%") << 90.0 << int(common::Severity::Critical);
    QTest::newRow("maximum") << 100.0 << int(common::Severity::Critical);
}

void TestReading::severityThresholds()
{
    QFETCH(double, value);
    QFETCH(int, expected);
    Reading r(QStringLiteral("FiO2"), QStringLiteral("%"), value, Range { 0.0, 100.0 });
    QCOMPARE(int(r.severity()), expected);
}

void TestReading::degenerateRangeIsSafe()
{
    // A zero-width range must not divide by zero.
    Reading r(QStringLiteral("Broken"), QString(), 42.0, Range { 5.0, 5.0 });
    QCOMPARE(r.value(), 5.0);
    QCOMPARE(r.progress(), 0.0);
    QCOMPARE(int(r.severity()), int(common::Severity::Normal));
}

void TestReading::equalityComparesEveryField()
{
    const Range range { 0.0, 10.0 };
    Reading a(QStringLiteral("A"), QStringLiteral("u"), 1.0, range);
    Reading b(QStringLiteral("A"), QStringLiteral("u"), 1.0, range);
    QVERIFY(a == b);

    b.setValue(2.0);
    QVERIFY(a != b);

    Reading differentUnit(QStringLiteral("A"), QStringLiteral("v"), 1.0, range);
    QVERIFY(a != differentUnit);
}

void TestReading::benchmarkClamp()
{
    constexpr Range r { 0.0, 60.0 };
    QBENCHMARK
    {
        for (int i = -1000; i < 1000; ++i)
            (void)r.clamp(i);
    }
}

QTEST_MAIN(TestReading)
#include "tst_reading.moc"
