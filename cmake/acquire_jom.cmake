# cmake/acquire_jom.cmake
# Downloads and installs JOM (Qt's parallel nmake replacement) (Windows only)
#
# Configurable variables:
#   JOM_VERSION - JOM version (default: 1_1_4)
#
# Output variables:
#   JOM_EXECUTABLE - Full path to jom.exe
#   JOM_BIN_DIR    - Directory containing jom.exe
#
# Download URL:
#   https://download.qt.io/official_releases/jom/jom_<version>.zip

if (NOT DEFINED JOM_VERSION)
    set(JOM_VERSION "1_1_4")
endif()

set(_jom_install_dir "${CMAKE_CURRENT_SOURCE_DIR}/tools/jom")
set(_jom_zip         "${CMAKE_CURRENT_SOURCE_DIR}/tools/jom.zip")

# Create the tools directory
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/tools")

# If already installed, only perform the search
file(GLOB _jom_exe_candidates "${_jom_install_dir}/jom.exe")

if (NOT _jom_exe_candidates)
    set(_jom_urls
        "https://download.qt.io/official_releases/jom/jom_${JOM_VERSION}.zip"
        "https://download.qt.io/archive/jom/jom_${JOM_VERSION}.zip"
    )

    set(_download_ok FALSE)
    foreach(_url ${_jom_urls})
        message(STATUS "[JOM] Trying: ${_url}")
        file(DOWNLOAD
            "${_url}"
            "${_jom_zip}"
            STATUS  _download_status
            TIMEOUT 120
        )
        list(GET _download_status 0 _status_code)
        if (_status_code EQUAL 0)
            set(_download_ok TRUE)
            message(STATUS "[JOM] Download succeeded.")
            break()
        else()
            list(GET _download_status 1 _status_msg)
            message(STATUS "[JOM] Failed (code=${_status_code}): ${_status_msg}")
            file(REMOVE "${_jom_zip}")
        endif()
    endforeach()

    if (NOT _download_ok)
        message(FATAL_ERROR
            "[JOM] All download URLs failed for JOM ${JOM_VERSION}.\n"
            "Manually download jom_${JOM_VERSION}.zip from https://download.qt.io/official_releases/jom/ and\n"
            "extract it into ${_jom_install_dir}, or check the JOM_VERSION variable."
        )
    endif()

    message(STATUS "[JOM] Extracting to ${_jom_install_dir}...")
    file(MAKE_DIRECTORY "${_jom_install_dir}")
    # file(ARCHIVE_EXTRACT) is CMake 3.18+ only -> use cmake -E tar for 3.15 compatibility
    # (it is libarchive-based, so it auto-detects zip from the extension)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E tar xf "${_jom_zip}"
        WORKING_DIRECTORY "${_jom_install_dir}"
        RESULT_VARIABLE _extract_result
    )
    if (NOT _extract_result EQUAL 0)
        file(REMOVE "${_jom_zip}")
        message(FATAL_ERROR "[JOM] zip extraction failed (exit=${_extract_result}): ${_jom_zip}")
    endif()
    file(REMOVE "${_jom_zip}")

    file(GLOB _jom_exe_candidates "${_jom_install_dir}/jom.exe")
    if (NOT _jom_exe_candidates)
        message(FATAL_ERROR
            "[JOM] jom.exe not found after extraction.\n"
            "Install dir: ${_jom_install_dir}"
        )
    endif()

    message(STATUS "[JOM] Installation complete.")
else()
    message(STATUS "[JOM] Already installed, skipping download.")
endif()

list(GET _jom_exe_candidates 0 JOM_EXECUTABLE)
get_filename_component(JOM_BIN_DIR "${JOM_EXECUTABLE}" DIRECTORY)

message(STATUS "[JOM] Executable : ${JOM_EXECUTABLE}")
message(STATUS "[JOM] Bin dir    : ${JOM_BIN_DIR}")
