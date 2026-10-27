# One interface target carrying every compile setting. Each library links it
# PRIVATE, so warning policy is declared once and applied everywhere.
add_library(smarton_compile_settings INTERFACE)
add_library(SmarTon::compile_settings ALIAS smarton_compile_settings)

if(MSVC)
    target_compile_options(smarton_compile_settings INTERFACE /W4 /permissive-)
    if(ST_WARNINGS_AS_ERRORS)
        target_compile_options(smarton_compile_settings INTERFACE /WX)
    endif()
else()
    target_compile_options(smarton_compile_settings INTERFACE
        -Wall -Wextra -Wpedantic
        -Wshadow -Wnon-virtual-dtor -Wcast-align
        -Wunused -Woverloaded-virtual -Wnull-dereference -Wdouble-promotion
    )
    if(ST_WARNINGS_AS_ERRORS)
        target_compile_options(smarton_compile_settings INTERFACE -Werror)
    endif()
endif()

target_compile_definitions(smarton_compile_settings INTERFACE
    QT_DISABLE_DEPRECATED_BEFORE=0x060800
    $<$<CONFIG:Release>:QT_NO_DEBUG_OUTPUT>
)
