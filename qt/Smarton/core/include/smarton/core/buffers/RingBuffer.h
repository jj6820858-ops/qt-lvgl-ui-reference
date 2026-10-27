#pragma once

#include <QtCore/QVector>

#include <cstddef>

namespace smarton::core {

/**
 * @brief Fixed-capacity circular buffer.
 *
 * Allocates once at construction and never again — which is why waveform and
 * telemetry history use it instead of a growing container. On an embedded
 * target, an allocation inside a 16 ms frame is a dropped frame.
 *
 * @tparam T element type; must be default-constructible.
 */
template<typename T>
class RingBuffer
{
public:
    explicit RingBuffer(int capacity) : m_data(capacity), m_capacity(capacity) { }

    [[nodiscard]] int capacity() const noexcept { return m_capacity; }
    [[nodiscard]] int size() const noexcept { return m_size; }
    [[nodiscard]] bool isEmpty() const noexcept { return m_size == 0; }
    [[nodiscard]] bool isFull() const noexcept { return m_size == m_capacity; }

    void append(const T &value)
    {
        if (m_capacity == 0)
            return;

        m_data[m_head] = value;
        m_head = (m_head + 1) % m_capacity;
        if (m_size < m_capacity)
            ++m_size;
    }

    /** Element @p i counting from the oldest retained value. */
    [[nodiscard]] const T &at(int i) const
    {
        const int start = (m_head - m_size + m_capacity) % m_capacity;
        return m_data.at((start + i) % m_capacity);
    }

    /** Most recently appended element. Undefined when empty. */
    [[nodiscard]] const T &last() const
    {
        return m_data.at((m_head - 1 + m_capacity) % m_capacity);
    }

    void clear() noexcept
    {
        m_head = 0;
        m_size = 0;
    }

private:
    QVector<T> m_data;
    int m_capacity = 0;
    int m_head = 0;
    int m_size = 0;
};

} // namespace smarton::core
