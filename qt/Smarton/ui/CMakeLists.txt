# Each SmarTon.Ui.* QML module, added in dependency order.
#
#   Theme      design tokens                (imports SmarTon.Backend)
#   Helpers    pure JS utilities            (no dependencies)
#   Controls   atoms — buttons, gauges      (Theme, Helpers)
#   Layouts    arrangement primitives       (Theme)
#   Components molecules built from atoms   (Theme, Controls, Layouts)
#   Navigation nav rail, tab bars           (Theme, Controls)
#   Dialogs    modal surfaces               (Theme, Controls, Layouts)
#   Screens    full pages                   (everything above + Models)
#
# A module may only import modules listed above it. Adding an import that
# points downward means two modules should be merged, or a type belongs lower.
add_subdirectory(Theme)
add_subdirectory(Helpers)
add_subdirectory(Controls)
add_subdirectory(Layouts)
add_subdirectory(Components)
# Optional: only when Qt Quick 3D is available. The Rooms screen falls back to
# the 2D plan when it is not, so this is an addition rather than a requirement.
if(ST_HAS_QUICK3D)
    add_subdirectory(Map3D)
endif()
if(ST_HAS_PARTICLES)
    add_subdirectory(Effects)
endif()
add_subdirectory(Navigation)
add_subdirectory(Dialogs)
add_subdirectory(Screens)
