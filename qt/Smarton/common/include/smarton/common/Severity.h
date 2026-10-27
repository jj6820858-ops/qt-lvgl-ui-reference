#pragma once

#include <QtCore/QtGlobal>

namespace smarton::common {

/**
 * @brief How urgently a value needs attention.
 *
 * Lives in `common` rather than `domain` because both the domain layer and
 * the UI layer need it, and neither should depend on the other.
 */
enum class Severity : quint8 {
    Normal = 0,
    Warning = 1,
    Critical = 2,
};

/** Highest of two severities. */
[[nodiscard]] constexpr Severity worse(Severity a, Severity b) noexcept
{
    return (a > b) ? a : b;
}

} // namespace smarton::common
