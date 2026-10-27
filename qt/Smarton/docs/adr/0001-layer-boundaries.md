# 1. Enforce layer boundaries with CMake link lists

Status: Accepted

## Context

Layered architecture usually degrades the same way: someone adds an `#include`
that points the wrong direction, nobody notices in review, and six months later
the domain layer cannot be compiled without a QML engine.

Comments and folder names do not prevent this. Only the build can.

## Decision

Each layer is a separate CMake target with an explicit `target_link_libraries`
list. `smarton_domain` links `Qt6::Core` and `SmarTon::common` and
nothing else. Public headers live under `include/smarton/<layer>/` and are
included angle-bracketed, so a wrong-direction include fails to resolve rather
than silently working through a relative path.

Adding a dependency is therefore a visible edit to a `CMakeLists.txt` — the
kind of change a reviewer notices.

## Consequences

+ The dependency rule is checkable by the compiler, not by discipline.
+ Domain and service logic are unit-testable in milliseconds, headless.
+ Layer diagrams in docs cannot drift from reality — the link lists are the
  diagram.
− More CMake files than a flat project.
− Genuinely shared code must be pushed down into `common`, which is a small
  ongoing design cost. It is also the point.
