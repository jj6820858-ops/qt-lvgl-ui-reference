#include <QtTest>

#include <smarton/core/buffers/RingBuffer.h>

using smarton::core::RingBuffer;

class TestRingBuffer : public QObject
{
    Q_OBJECT
private slots:
    void startsEmpty();
    void fillsThenWraps();
    void atCountsFromOldest();
    void clearResets();
    void zeroCapacityIsSafe();
};

void TestRingBuffer::startsEmpty()
{
    RingBuffer<int> b(4);
    QCOMPARE(b.capacity(), 4);
    QCOMPARE(b.size(), 0);
    QVERIFY(b.isEmpty());
    QVERIFY(!b.isFull());
}

void TestRingBuffer::fillsThenWraps()
{
    RingBuffer<int> b(3);
    b.append(1);
    b.append(2);
    b.append(3);
    QVERIFY(b.isFull());
    QCOMPARE(b.size(), 3);
    QCOMPARE(b.last(), 3);

    b.append(4); // evicts the oldest
    QCOMPARE(b.size(), 3); // size never exceeds capacity
    QCOMPARE(b.last(), 4);
    QCOMPARE(b.at(0), 2); // 1 is gone
}

void TestRingBuffer::atCountsFromOldest()
{
    RingBuffer<int> b(3);
    for (int i = 1; i <= 5; ++i)
        b.append(i);
    QCOMPARE(b.at(0), 3);
    QCOMPARE(b.at(1), 4);
    QCOMPARE(b.at(2), 5);
}

void TestRingBuffer::clearResets()
{
    RingBuffer<int> b(2);
    b.append(1);
    b.clear();
    QVERIFY(b.isEmpty());
    QCOMPARE(b.size(), 0);
}

void TestRingBuffer::zeroCapacityIsSafe()
{
    RingBuffer<int> b(0);
    b.append(7); // must not crash or divide by zero
    QCOMPARE(b.size(), 0);
    QVERIFY(b.isEmpty());
}

QTEST_MAIN(TestRingBuffer)
#include "tst_ringbuffer.moc"
