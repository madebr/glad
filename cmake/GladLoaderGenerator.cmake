find_program(GLAD_BIN
    NAMES glad
    HINTS
        "$ENV{HOME}/.local/bin"
    )

if(NOT GLAD_BIN)
    message(FATAL_ERROR "Cannot find glad program.")
endif()

# Extract specification, profile and version from a string
# examples:
# gl:core=3.3          => SPEC=gl     PROFILE=core          VERSION=3.3
# gl:compatibility=4.0 => SPEC=gl     PROFILE=compatibility VERSION=4.0
# vulkan=1.1           => SPEC=vulkan PROFILE=""            VERSION=1.1
function(__glad_extract_spec_profile_version SPEC PROFILE VERSION STRING)
    string(REPLACE "=" ";" SPEC_PROFILE_VERSION_LIST "${STRING}")
    list(LENGTH SPEC_PROFILE_VERSION_LIST SPV_LENGTH)
    if(SPV_LENGTH LESS 2)
        message(FATAL_ERROR "${SPEC} is an invalid SPEC")
    endif()
    list(GET SPEC_PROFILE_VERSION_LIST 0 SPEC_PROFILE_STR)
    list(GET SPEC_PROFILE_VERSION_LIST 1 VERSION_STR)

    string(REPLACE ":" ";" SPEC_PROFILE_LIST "${SPEC_PROFILE_STR}")
    list(LENGTH SPEC_PROFILE_LIST SP_LENGTH)
    if(SP_LENGTH LESS 2)
        list(GET SPEC_PROFILE_LIST 0 SPEC_STR)
        set(PROFILE_STR "")
    else()
        list(GET SPEC_PROFILE_LIST 0 SPEC_STR)
        list(GET SPEC_PROFILE_LIST 1 PROFILE_STR)
    endif()

    set("${SPEC}" "${SPEC_STR}" PARENT_SCOPE)
    set("${PROFILE}" "${PROFILE_STR}" PARENT_SCOPE)
    set("${VERSION}" "${VERSION_STR}" PARENT_SCOPE)
endfunction()

# Calculate the argument and generated files for the "c" subparser for glad
function(__glad_c_library CARGS CFILES)
    cmake_parse_arguments(GGC "ALIAS;DEBUG;HEADERONLY;LOADER;MX;MXGLOBAL" "" "API" ${ARGN})

    if(NOT GGC_API)
        message(FATAL_ERROR "Need API")
    endif()

    set(GGC_FILES "")
    foreach(API ${GGC_API})
        __glad_extract_spec_profile_version(SPEC PROFILE VERSION "${API}")
        if(SPEC STREQUAL "egl")
            list(APPEND GGC_FILES
                "${GLAD_DIR}/include/EGL/eglplatform.h"
                "${GLAD_DIR}/include/KHR/khrplatform.h"
                "${GLAD_DIR}/include/glad/egl.h"
                "${GLAD_DIR}/src/egl.c"
                )
        elseif(SPEC STREQUAL "vulkan")
            list(APPEND GGC_FILES
                "${GLAD_DIR}/include/vk_platform.h"
                "${GLAD_DIR}/include/glad/vulkan.h"
                "${GLAD_DIR}/src/vulkan.c"
                )
        elseif(SPEC STREQUAL "gl")
            list(APPEND GGC_FILES
                "${GLAD_DIR}/include/KHR/khrplatform.h"
                "${GLAD_DIR}/include/glad/gl.h"
                "${GLAD_DIR}/src/gl.c"
                )
        elseif(SPEC STREQUAL "gles1")
            list(APPEND GGC_FILES
                "${GLAD_DIR}/include/KHR/khrplatform.h"
                "${GLAD_DIR}/include/glad/gles1.h"
                "${GLAD_DIR}/src/gles1.c"
                )
        elseif(SPEC STREQUAL "gles2")
            list(APPEND GGC_FILES
                "${GLAD_DIR}/include/KHR/khrplatform.h"
                "${GLAD_DIR}/include/glad/gles2.h"
                "${GLAD_DIR}/src/gles2.c"
                )
        elseif(SPEC STREQUAL "gles3")
            list(APPEND GGC_FILES
                "${GLAD_DIR}/include/KHR/khrplatform.h"
                "${GLAD_DIR}/include/glad/gles3.h"
                "${GLAD_DIR}/src/gles3.c"
                )
        elseif(SPEC STREQUAL "glsc2")
            list(APPEND GGC_FILES
                "${GLAD_DIR}/include/KHR/khrplatform.h"
                "${GLAD_DIR}/include/glad/glsc2.h"
                "${GLAD_DIR}/src/glsc2.c"
                )
        elseif(SPEC STREQUAL "wgl")
            list(APPEND GGC_FILES
                "${GLAD_DIR}/include/glad/wgl.h"
                "${GLAD_DIR}/src/wgl.c"
                )
        elseif(SPEC STREQUAL "glx")
            list(APPEND GGC_FILES
                "${GLAD_DIR}/include/glad/glx.h"
                "${GLAD_DIR}/src/glx.c"
                )
        else()
            message(FATAL_ERROR "Unknown SPEC: '${SPEC}'")
        endif()
    endforeach()

    set(GGC_ARGS "")
    if(GGC_ALIAS)
        list(APPEND GGC_ARGS "--alias")
    endif()

    if(GGC_DEBUG)
        list(APPEND GGC_ARGS "--debug")
    endif()

    if(GGC_HEADERONLY)
        list(APPEND GGC_ARGS "--header-only")
    endif()

    if(GGC_LOADER)
        list(APPEND GGC_ARGS "--loader")
    endif()

    if(GGC_MX)
        list(APPEND GGC_ARGS "--mx")
    endif()

    if(GGC_MXGLOBAL)
        list(APPEND GGC_ARGS "--mx-global")
    endif()

    set("${CARGS}" "${GGC_ARGS}" PARENT_SCOPE)
    set("${CFILES}" "${GGC_FILES}" PARENT_SCOPE)
endfunction()

# Create a glad library named "${TARGET}"
function(glad_add_library TARGET)
    cmake_parse_arguments(GG "MERGE;QUIET;EXCLUDE_FROM_ALL" "LOCATION;LANGUAGE" "API;EXTENSIONS" ${ARGN})

    if(NOT GG_LOCATION)
        message(FATAL_ERROR "Need LOCATION")
    endif()
    set(GLAD_DIR "${GG_LOCATION}")
    if(NOT IS_DIRECTORY "${GLAD_DIR}")
        file(MAKE_DIRECTORY "${GLAD_DIRECTORY}")
    endif()
    set(GLAD_ARGS --out-path "${GLAD_DIR}")

    if(NOT GG_API)
        message(FATAL_ERROR "Need API")
    endif()
    string(REPLACE ";" "," GLAD_API "${GG_API}")
    list(APPEND GLAD_ARGS  --api "${GLAD_API}")

    if(GG_EXTENSIONS)
        string(REPLACE ";" "," GLAD_EXTENSIONS ${GG_EXTENSIONS})
        list(APPEND GLAD_ARGS --extensions "${GLAD_EXTENSIONS}")
    endif()

    if(GG_QUIET)
        list(APPEND GLAD_ARGS --quiet)
    endif()

    if(GG_MERGE)
        list(APPEND GLAD_ARGS --merge)
    endif()

    set(GLAD_LANGUAGE "c")
    if(GG_LANGUAGE)
        string(TOLOWER "${GG_LANGUAGE}" "${GLAD_LANGUAGE}")
    endif()

    if(GLAD_LANGUAGE STREQUAL "c")
        __glad_c_library(LANG_ARGS GLAD_FILES ${GG_UNPARSED_ARGUMENTS} API ${GG_API})
    else()
        message(FATAL_ERROR "Unknown LANGUAGE")
    endif()
    list(APPEND GLAD_ARGS ${GLAD_LANGUAGE} ${LANG_ARGS})

    # allows:
    # - bootstrap: generate sources when non-existent
    # - do not remove the sources when cleaning
    # BUG: running clean directly after an initial make without sources present, removes the sources
    set(GLAD_OUT_OF_DATE OFF)
    set(GLAD_ARGS_PATH "${GLAD_DIR}/args.txt")
    if(NOT EXISTS "${GLAD_ARGS_PATH}")
        set(GLAD_OUT_OF_DATE ON)
    else()
        file(READ "${GLAD_ARGS_PATH}" GLAD_ARGS_FILE)
        if(NOT GLAD_ARGS STREQUAL GLAD_ARGS_FILE)
            set(GLAD_OUT_OF_DATE ON)
        endif()
    endif()

    # regenerate files when argument changes
    if(GLAD_OUT_OF_DATE)
        add_custom_command(OUTPUT ${GLAD_FILES} ${GLAD_ARGS_PATH}
            COMMAND "${CMAKE_COMMAND}" -E remove_directory "${GLAD_DIR}"
            COMMAND "${GLAD_BIN}" ${GLAD_ARGS}
            COMMAND "${CMAKE_COMMAND}" "-DPATH=${GLAD_ARGS_PATH}" "-DTEXT=\"${GLAD_ARGS}\"" -P "${GLAD_MODULE_PATH}/WriteFile.cmake"
            COMMAND "${CMAKE_COMMAND}" -E sleep 1
            COMMAND "${CMAKE_COMMAND}" -E touch "${CMAKE_CURRENT_LIST_FILE}"
            )
    endif()

    # add make custom target
    add_custom_target("regenerate_${TARGET}"
        COMMAND "${CMAKE_COMMAND}" -E remove_directory "${GLAD_DIR}"
        COMMAND "${GLAD_BIN}" ${GLAD_ARGS}
        COMMAND "${CMAKE_COMMAND}" "-DPATH=${GLAD_ARGS_PATH}" "-DTEXT=\"${GLAD_ARGS}\"" -P "${GLAD_MODULE_PATH}/WriteFile.cmake"
        COMMAND "${CMAKE_COMMAND}" -E sleep 1
        COMMAND "${CMAKE_COMMAND}" -E touch "${CMAKE_CURRENT_LIST_FILE}"
        COMMENT "Regenerating glad source files for ${TARGET}..."
        )

    set(GLAD_ADD_LIBRARY_ARGS "")
    if(GG_EXCLUDE_FROM_ALL)
        list(APPEND GLAD_ADD_LIBRARY_ARGS EXCLUDE_FROM_ALL)
    endif()

    add_library("${TARGET}" ${GLAD_ADD_LIBRARY_ARGS}
        ${GLAD_FILES}
        )

    target_include_directories("${TARGET}"
        PUBLIC
            "${GLAD_DIR}/include"
        )

    target_link_libraries("${TARGET}"
        PUBLIC
            ${CMAKE_DL_LIBS}
        )
endfunction()
