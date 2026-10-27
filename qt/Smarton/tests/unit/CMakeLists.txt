# One executable per test class; each registered with CTest by name.
function(st_add_unit_test name)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "" "" "SOURCES;LIBRARIES")
    qt_add_executable(tst_${name} ${ARG_SOURCES})
    target_link_libraries(tst_${name} PRIVATE
        Qt6::Test
        SmarTon::compile_settings
        ${ARG_LIBRARIES}
    )
    add_test(NAME ${name} COMMAND tst_${name})
endfunction()

st_add_unit_test(reading
    SOURCES   tst_reading.cpp
    LIBRARIES SmarTon::domain)

st_add_unit_test(ringbuffer
    SOURCES   tst_ringbuffer.cpp
    LIBRARIES SmarTon::core)

st_add_unit_test(monitoringservice
    SOURCES   tst_monitoringservice.cpp
    LIBRARIES SmarTon::services SmarTon::infrastructure)

st_add_unit_test(readinglistmodel
    SOURCES   tst_readinglistmodel.cpp
    LIBRARIES SmarTon::models)

st_add_unit_test(passwordhashing
    SOURCES   tst_passwordhashing.cpp
    LIBRARIES SmarTon::infrastructure)

st_add_unit_test(authservice
    SOURCES   tst_authservice.cpp
    LIBRARIES SmarTon::services SmarTon::domain)

st_add_unit_test(authviewmodel
    SOURCES   tst_authviewmodel.cpp
    LIBRARIES SmarTon::models)

st_add_unit_test(homeservice
    SOURCES   tst_homeservice.cpp
    LIBRARIES SmarTon::services SmarTon::domain)

st_add_unit_test(scenescheduler
    SOURCES   tst_scenescheduler.cpp
    LIBRARIES SmarTon::services SmarTon::domain)

st_add_unit_test(devicetransport
    SOURCES   tst_devicetransport.cpp
    LIBRARIES SmarTon::infrastructure SmarTon::services SmarTon::domain)

st_add_unit_test(appearance
    SOURCES   tst_appearance.cpp
    LIBRARIES SmarTon::backend SmarTon::infrastructure)

st_add_unit_test(activitylog
    SOURCES   tst_activitylog.cpp
    LIBRARIES SmarTon::services SmarTon::domain)

st_add_unit_test(sessiontokens
    SOURCES   tst_sessiontokens.cpp
    LIBRARIES SmarTon::services SmarTon::domain)
