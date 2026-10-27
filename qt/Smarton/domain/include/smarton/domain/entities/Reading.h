#pragma once

#include <smarton/common/Severity.h>
#include <smarton/domain/valueobjects/Range.h>

#include <QtCore/QString>

namespace smarton::domain {

/**
 * @brief A named sensor reading constrained to a range.
 *
 * @note Out-of-range input is clamped, never rejected — a display must always
 *       have something valid to show. See docs/adr/0002-clamp-instead-of-reject.md.
 */
class Reading
{
public:
    Reading() = default;
    Reading(QString label, QString unit, double value, Range range);

    [[nodiscard]] QString label() const { return m_label; }
    [[nodiscard]] QString unit() const { return m_unit; }
    [[nodiscard]] double value() const { return m_value; }
    [[nodiscard]] Range range() const { return m_range; }

    [[nodiscard]] double progress() const;
    [[nodiscard]] common::Severity severity() const;

    void setValue(double v);

    friend bool operator==(const Reading &a, const Reading &b);
    friend bool operator!=(const Reading &a, const Reading &b) { return !(a == b); }

private:
    QString m_label;
    QString m_unit;
    double m_value = 0.0;
    Range m_range;
};

} // namespace smarton::domain
