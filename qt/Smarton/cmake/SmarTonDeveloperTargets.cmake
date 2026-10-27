# Aggregate convenience targets. Call st_add_developer_targets() once, after
# every subdirectory has been added, so the global module lists are complete.
function(st_add_developer_targets)
    get_property(_uris    GLOBAL PROPERTY ST_QML_MODULE_URIS)
    get_property(_targets GLOBAL PROPERTY ST_QML_MODULE_TARGETS)

    list(LENGTH _uris _count)
    message(STATUS "  QML modules     : ${_count}")
    foreach(_uri IN LISTS _uris)
        message(STATUS "      ${_uri}")
    endforeach()

    # `cmake --build . --target st_lint` runs every generated qmllint target.
    if(ST_ENABLE_QMLLINT AND TARGET all_qmllint)
        add_custom_target(st_lint
            COMMENT "Running qmllint across every SmarTon QML module")
        add_dependencies(st_lint all_qmllint)
    endif()

    # Regenerates docs/generated/QmlCatalog.md — an index of every QML type.
    add_custom_target(st_qml_catalog
        COMMAND ${CMAKE_COMMAND}
            -DAT_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DAT_OUTPUT_FILE=${CMAKE_SOURCE_DIR}/docs/generated/QmlCatalog.md
            -P ${CMAKE_SOURCE_DIR}/cmake/SmarTonQmlCatalog.cmake
        COMMENT "Generating QML component catalog"
        VERBATIM)
endfunction()
