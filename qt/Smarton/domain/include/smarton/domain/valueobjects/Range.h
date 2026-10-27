#pragma once

#include <algorithm>

namespace smarton::domain {

/**
 * @brief Inclusive numeric range with clamping.
 *
 * A value object: no identity, cheap to copy, compared by value.
 */
struct Range
{
    double minimum = 0.0;
    double maximum = 100.0;

    [[nodiscard]] constexpr bool isValid() const noexcept { return maximum > minimum; }

    [[nodiscard]] constexpr bool contains(double v) const noexcept
    {
        return v >= minimum && v <= maximum;
    }

    [[nodiscard]] constexpr double clamp(double v) const noexcept
    {
        if (!isValid())
            return minimum;
        return std::clamp(v, minimum, maximum);
    }

    /** Position of @p v within the range, normalised to [0.0, 1.0]. */
    [[nodiscard]] constexpr double normalise(double v) const noexcept
    {
        if (!isValid())
            return 0.0;
        return (clamp(v) - minimum) / (maximum - minimum);
    }

    friend constexpr bool operator==(const Range &, const Range &) = default;
};

} // namespace smarton::domain
