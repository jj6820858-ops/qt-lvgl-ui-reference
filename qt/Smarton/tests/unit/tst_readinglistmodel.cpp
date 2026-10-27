#include <QAbstractItemModelTester>
#include <QSignalSpy>
#include <QtTest>

#include <smarton/models/ReadingListModel.h>

using namespace smarton;
using domain::Range;
using domain::Reading;
using models::ReadingListModel;

namespace {

QVector<Reading> makeTwo(double a, double b)
{
    return {
        Reading(QStringLiteral("Pressure"), QStringLiteral("cmH2O"), a, Range { 0.0, 60.0 }),
        Reading(QStringLiteral("Volume"), QStringLiteral("mL"), b, Range { 0.0, 800.0 }),
    };
}

} // namespace

class TestReadingListModel : public QObject
{
    Q_OBJECT
private slots:
    void passesQtModelConformance();
    void exposesEveryRole();
    void identicalUpdateEmitsNothing();
    void changedRowEmitsDataChangedOnly();
    void rowCountChangeResetsModel();
    void invalidIndexReturnsInvalidVariant();
};

void TestReadingListModel::passesQtModelConformance()
{
    ReadingListModel model;
    QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
    model.setReadings(makeTwo(10.0, 100.0));
}

void TestReadingListModel::exposesEveryRole()
{
    ReadingListModel model;
    model.setReadings(makeTwo(30.0, 0.0));

    const auto names = model.roleNames().values();
    for (const auto &expected :
         { "label", "unit", "value", "minimum", "maximum", "progress", "severity" }) {
        QVERIFY2(names.contains(QByteArray(expected)),
                 qPrintable(QStringLiteral("missing role: %1").arg(expected)));
    }

    const QModelIndex idx = model.index(0);
    QCOMPARE(model.data(idx, ReadingListModel::LabelRole).toString(), QStringLiteral("Pressure"));
    QCOMPARE(model.data(idx, ReadingListModel::UnitRole).toString(), QStringLiteral("cmH2O"));
    QVERIFY(qAbs(model.data(idx, ReadingListModel::ProgressRole).toDouble() - 0.5) < 0.0001);
}

void TestReadingListModel::identicalUpdateEmitsNothing()
{
    // The behaviour that stops QML bindings re-evaluating for no reason.
    ReadingListModel model;
    model.setReadings(makeTwo(10.0, 100.0));

    QSignalSpy dataSpy(&model, &QAbstractItemModel::dataChanged);
    QSignalSpy resetSpy(&model, &QAbstractItemModel::modelReset);

    model.setReadings(makeTwo(10.0, 100.0)); // identical

    QCOMPARE(dataSpy.count(), 0);
    QCOMPARE(resetSpy.count(), 0);
}

void TestReadingListModel::changedRowEmitsDataChangedOnly()
{
    ReadingListModel model;
    model.setReadings(makeTwo(10.0, 100.0));

    QSignalSpy dataSpy(&model, &QAbstractItemModel::dataChanged);
    QSignalSpy resetSpy(&model, &QAbstractItemModel::modelReset);

    model.setReadings(makeTwo(55.0, 100.0)); // row 0 only

    QCOMPARE(resetSpy.count(), 0); // no delegate churn
    QCOMPARE(dataSpy.count(), 1);

    const auto args = dataSpy.takeFirst();
    QCOMPARE(args.at(0).toModelIndex().row(), 0);
    QCOMPARE(args.at(1).toModelIndex().row(), 0);
}

void TestReadingListModel::rowCountChangeResetsModel()
{
    ReadingListModel model;
    model.setReadings(makeTwo(10.0, 100.0));

    QSignalSpy resetSpy(&model, &QAbstractItemModel::modelReset);

    QVector<Reading> three = makeTwo(10.0, 100.0);
    three.append(Reading(QStringLiteral("FiO2"), QStringLiteral("%"), 50.0, Range { 21.0, 100.0 }));
    model.setReadings(three);

    QCOMPARE(model.rowCount(), 3);
    QCOMPARE(resetSpy.count(), 1);
}

void TestReadingListModel::invalidIndexReturnsInvalidVariant()
{
    ReadingListModel model;
    model.setReadings(makeTwo(10.0, 100.0));

    QVERIFY(!model.data(QModelIndex(), ReadingListModel::LabelRole).isValid());
    QVERIFY(!model.data(model.index(99), ReadingListModel::LabelRole).isValid());
    QVERIFY(!model.data(model.index(0), Qt::UserRole + 999).isValid());
}

QTEST_GUILESS_MAIN(TestReadingListModel)
#include "tst_readinglistmodel.moc"
