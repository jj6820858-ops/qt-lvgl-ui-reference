# Entities and value objects. Qt Core only — no Qml, no Quick, no Gui.
# If this target ever needs Qt6::Quick, the layering has been broken.
add_library(smarton_domain STATIC)
add_library(SmarTon::domain ALIAS smarton_domain)

target_sources(smarton_domain
    PUBLIC
        FILE_SET HEADERS
        BASE_DIRS include
        FILES
            include/smarton/domain/valueobjects/Range.h
            include/smarton/domain/valueobjects/PasswordHash.h
            include/smarton/domain/entities/Reading.h
            include/smarton/domain/entities/User.h
            include/smarton/domain/entities/HomeEntities.h
    PRIVATE
        src/entities/Reading.cpp
        src/entities/User.cpp
        src/valueobjects/PasswordHash.cpp
)

target_include_directories(smarton_domain PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

target_link_libraries(smarton_domain
    PUBLIC  SmarTon::common Qt6::Core
    PRIVATE SmarTon::compile_settings
)
