# Qt Quick Test. Files named tst_*.qml are discovered recursively by the
# harness; -platform offscreen lets them run on a headless CI runner.
qt_add_executable(tst_qml main.cpp)

target_link_libraries(tst_qml PRIVATE
    Qt6::QuickTest
    Qt6::Qml
    SmarTonUi::components
    SmarTonUi::controls
    SmarTonUi::layouts
    SmarTonUi::theme
    SmarTon::compile_settings
)

target_compile_definitions(tst_qml PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")

add_test(NAME qmltests COMMAND tst_qml -platform offscreen)
