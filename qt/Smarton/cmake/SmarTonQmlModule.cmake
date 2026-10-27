# ---------------------------------------------------------------------------
#  qmltyperegistrar and nested header layouts
#
#  For every type registered with QML_ELEMENT, qmltyperegistrar emits:
#
#      #if __has_include(<DesignTokens.h>)
#      #  include <DesignTokens.h>
#      #endif
#
#  It always uses the header's BASENAME, never the path you listed in
#  target_sources(). With an include/<ns>/<layer>/Name.h layout the basename is
#  not on the include path, __has_include() is false, the include is SILENTLY
#  dropped, and the generated file fails to compile with "use of undeclared
#  identifier" - pointing at the registration call, not at the missing include.
#
#  Two ways out: duplicate every header as a flat forwarding header next to
#  include/, or put each leaf directory on the include path. We do the latter,
#  PRIVATE, so only this target's generated file sees the short names while
#  everyone else still includes the fully qualified path.
# ---------------------------------------------------------------------------
function(st_add_header_dirs_for_registrar target)
    set(_root "${CMAKE_CURRENT_SOURCE_DIR}/include")
    if(NOT IS_DIRECTORY "${_root}")
        return()
    endif()

    file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${_root}/*.h")
    set(_dirs "")
    foreach(_header IN LISTS _headers)
        get_filename_component(_dir "${_header}" DIRECTORY)
        list(APPEND _dirs "${_dir}")
    endforeach()

    if(_dirs)
        list(REMOVE_DUPLICATES _dirs)
        target_include_directories(${target} PRIVATE ${_dirs})
    endif()
endfunction()

# Declares a QML module whose generated output mirrors its URI, so the build
# tree doubles as a QML import path for Qt Creator, qmlls and qmllint.
#
#   st_add_qml_module(<target> URI SmarTon.Ui.Controls [VERSION 1.0] <qt_add_qml_module args...>)
function(st_add_qml_module target)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "" "URI;VERSION" "")

    if(NOT ARG_URI)
        message(FATAL_ERROR "st_add_qml_module(${target}): URI is required")
    endif()
    if(NOT ARG_VERSION)
        set(ARG_VERSION 1.0)
    endif()

    string(REPLACE "." "/" _uri_path "${ARG_URI}")

    qt_add_qml_module(${target}
        URI              "${ARG_URI}"
        VERSION          "${ARG_VERSION}"
        RESOURCE_PREFIX  "/qt/qml"
        OUTPUT_DIRECTORY "${ST_QML_IMPORT_ROOT}/${_uri_path}"
        ${ARG_UNPARSED_ARGUMENTS}
    )

    target_link_libraries(${target} PRIVATE SmarTon::compile_settings)

    # Applied automatically so no module has to remember it.
    st_add_header_dirs_for_registrar(${target})

    set_property(GLOBAL APPEND PROPERTY ST_QML_MODULE_URIS    "${ARG_URI}")
    set_property(GLOBAL APPEND PROPERTY ST_QML_MODULE_TARGETS "${target}")
endfunction()
