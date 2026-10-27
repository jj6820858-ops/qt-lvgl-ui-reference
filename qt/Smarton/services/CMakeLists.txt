# Orchestrates domain entities. Knows nothing about transports or QML —
# infrastructure implements the interfaces declared here.
add_library(smarton_services STATIC)
add_library(SmarTon::services ALIAS smarton_services)

target_sources(smarton_services
    PUBLIC
        FILE_SET HEADERS
        BASE_DIRS include
        FILES
            include/smarton/services/IReadingSource.h
            include/smarton/services/MonitoringService.h
            include/smarton/services/IPasswordHasher.h
            include/smarton/services/IUserRepository.h
            include/smarton/services/AuthService.h
            include/smarton/services/HomeService.h
            include/smarton/services/IDeviceTransport.h
            include/smarton/services/IPreferences.h
            include/smarton/services/ISessionRepository.h
            include/smarton/services/ISessionTokenStore.h
            include/smarton/services/IAvatarStore.h
            include/smarton/services/SceneScheduler.h
            include/smarton/services/ActivityLog.h
    PRIVATE
        src/MonitoringService.cpp
        src/AuthService.cpp
        src/HomeService.cpp
        src/SceneScheduler.cpp
        src/ActivityLog.cpp
)

target_include_directories(smarton_services PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

target_link_libraries(smarton_services
    PUBLIC  SmarTon::domain SmarTon::core Qt6::Core
    PRIVATE SmarTon::compile_settings
)
