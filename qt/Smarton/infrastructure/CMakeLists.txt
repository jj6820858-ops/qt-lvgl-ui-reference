# Concrete implementations of service-layer interfaces: transports, simulators,
# persistence. This is the only layer allowed to know about the outside world.
add_library(smarton_infrastructure STATIC)
add_library(SmarTon::infrastructure ALIAS smarton_infrastructure)

target_sources(smarton_infrastructure
    PUBLIC
        FILE_SET HEADERS
        BASE_DIRS include
        FILES
            include/smarton/infrastructure/simulator/SimulatedReadingSource.h
            include/smarton/infrastructure/auth/Pbkdf2PasswordHasher.h
            include/smarton/infrastructure/persistence/SqliteUserRepository.h
            include/smarton/infrastructure/persistence/DatabaseConfig.h
            include/smarton/infrastructure/persistence/SqliteHomeStore.h
            include/smarton/infrastructure/transport/LoopbackDeviceTransport.h
            include/smarton/infrastructure/settings/QSettingsPreferences.h
            include/smarton/infrastructure/settings/QSettingsSessionTokenStore.h
            include/smarton/infrastructure/persistence/SqliteSessionRepository.h
            include/smarton/infrastructure/media/FileAvatarStore.h
            include/smarton/infrastructure/persistence/FileActivityStore.h
    PRIVATE
        src/simulator/SimulatedReadingSource.cpp
        src/auth/Pbkdf2PasswordHasher.cpp
        src/persistence/SqliteUserRepository.cpp
        src/persistence/DatabaseConfig.cpp
        src/persistence/SqliteHomeStore.cpp
        src/transport/LoopbackDeviceTransport.cpp
        src/settings/QSettingsPreferences.cpp
        src/settings/QSettingsSessionTokenStore.cpp
        src/persistence/SqliteSessionRepository.cpp
        src/media/FileAvatarStore.cpp
        src/persistence/FileActivityStore.cpp
)

target_include_directories(smarton_infrastructure PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

target_link_libraries(smarton_infrastructure
    PUBLIC  SmarTon::services Qt6::Core Qt6::Gui Qt6::Sql Qt6::Network
    PRIVATE SmarTon::compile_settings
)

# The MQTT transport is compiled only where Qt MQTT exists. Added to the target
# rather than built as a second library: it is one more implementation of an
# interface this layer already owns, and a library per optional class would be
# a link list nobody can read. See ADR-0019.
if(ST_HAS_MQTT)
    target_sources(smarton_infrastructure
        PUBLIC
            FILE_SET HEADERS
            BASE_DIRS include
            FILES
                include/smarton/infrastructure/transport/MqttDeviceTransport.h
        PRIVATE
            src/transport/MqttDeviceTransport.cpp
    )
    target_link_libraries(smarton_infrastructure PUBLIC Qt6::Mqtt)
    target_compile_definitions(smarton_infrastructure PUBLIC ST_HAS_MQTT)
else()
    # CMake's AUTOMOC include scanner sees the conditionally included header
    # in app/main.cpp even when ST_HAS_MQTT is absent. Do not generate a moc
    # object that would reference an implementation intentionally not built.
    set_source_files_properties(
        include/smarton/infrastructure/transport/MqttDeviceTransport.h
        PROPERTIES SKIP_AUTOMOC ON)
endif()
