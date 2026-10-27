# Qt Linguist catalogues.
#
# Wired up from day one even with a single language: retrofitting qsTr() into
# a finished UI is far more work than never skipping it.
#
# Guarded in the root CMakeLists by Qt6LinguistTools_FOUND — qt_add_translations()
# comes from the LinguistTools package, which a minimal or cross-compiled Qt
# install may not ship.
qt_add_translations(smarton
    TS_FILES
        smarton_en.ts
    LUPDATE_OPTIONS -no-obsolete
)
