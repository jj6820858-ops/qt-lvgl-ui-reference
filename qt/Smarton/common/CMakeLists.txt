# Vocabulary types shared by every layer. Header-only, zero dependencies
# beyond Qt Core — this is the bottom of the stack.
add_library(smarton_common INTERFACE)
add_library(SmarTon::common ALIAS smarton_common)

target_sources(smarton_common INTERFACE
    FILE_SET HEADERS
    BASE_DIRS include
    FILES
        include/smarton/common/Severity.h
)

target_include_directories(smarton_common INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(smarton_common INTERFACE Qt6::Core)
