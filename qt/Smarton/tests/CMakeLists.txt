# Tests mirror the layer they cover. A test that needs a QML engine to check a
# domain rule is a sign the rule is in the wrong layer.
#
#   unit/  Qt Test        — domain, services, models
#   qml/   Qt Quick Test  — controls and components, headless
add_subdirectory(unit)
add_subdirectory(qml)
