#include <smarton/domain/entities/Reading.h>

#include <utility>

namespace smarton::domain {

namespace {
constexpr double kWarningThreshold = 0.75;
constexpr double kCriticalThreshold = 0.90;
} // namespace

Reading::Reading(QString label, QString unit, double value, Range range)
    : m_label(std::move(label))
    , m_unit(std::move(unit))
    , m_value(range.clamp(value))
    , m_range(range)
{
}

double Reading::progress() const
{
    return m_range.normalise(m_value);
}

common::Severity Reading::severity() const
{
    const double p = progress();
    if (p >= kCriticalThreshold)
        return common::Severity::Critical;
    if (p >= kWarningThreshold)
        return common::Severity::Warning;
    return common::Severity::Normal;
}

void Reading::setValue(double v)
{
    m_value = m_range.clamp(v);
}

bool operator==(const Reading &a, const Reading &b)
{
    return a.m_label == b.m_label && a.m_unit == b.m_unit && a.m_range == b.m_range
        && qFuzzyCompare(a.m_value + 1.0, b.m_value + 1.0);
}

} // namespace smarton::domain
