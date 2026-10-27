# Framework primitives — data structures and algorithms with no domain meaning.
add_library(smarton_core INTERFACE)
add_library(SmarTon::core ALIAS smarton_core)

target_sources(smarton_core INTERFACE
    FILE_SET HEADERS
    BASE_DIRS include
    FILES
        include/smarton/core/buffers/RingBuffer.h
)

target_include_directories(smarton_core INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(smarton_core INTERFACE SmarTon::common)
