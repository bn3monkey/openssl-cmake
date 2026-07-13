# cmake/acquire_nasm.cmake
# Downloads and installs NASM (Netwide Assembler) (Windows only)
#
# Configurable variables:
#   NASM_VERSION - NASM version (default: 3.01)
#
# Output variables:
#   NASM_EXECUTABLE - Full path to nasm.exe
#   NASM_BIN_DIR    - Directory containing nasm.exe
#
# Download URL priority:
#   1. https://www.nasm.us/pub/nasm/releasebuilds/...
#   2. https://www.nasm.dev/pub/nasm/releasebuilds/...
#   3. https://vcpkg.github.io/assets/nasm/...

if (NOT DEFINED NASM_VERSION)
    set(NASM_VERSION "3.01")
endif()

set(_nasm_install_dir "${CMAKE_CURRENT_SOURCE_DIR}/tools/nasm")
set(_nasm_zip         "${CMAKE_CURRENT_SOURCE_DIR}/tools/nasm.zip")

# Create the tools directory
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/tools")

# If already installed, only perform the search
file(GLOB_RECURSE _nasm_exe_candidates "${_nasm_install_dir}/nasm.exe")

if (NOT _nasm_exe_candidates)
    set(_nasm_urls
        "https://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/win64/nasm-${NASM_VERSION}-win64.zip"
        "https://www.nasm.dev/pub/nasm/releasebuilds/${NASM_VERSION}/win64/nasm-${NASM_VERSION}-win64.zip"
        "https://vcpkg.github.io/assets/nasm/nasm-${NASM_VERSION}-win64.zip"
    )

    set(_download_ok FALSE)
    foreach(_url ${_nasm_urls})
        message(STATUS "[NASM] Trying: ${_url}")
        file(DOWNLOAD
            "${_url}"
            "${_nasm_zip}"
            STATUS  _download_status
            TIMEOUT 120
        )
        list(GET _download_status 0 _status_code)
        if (_status_code EQUAL 0)
            set(_download_ok TRUE)
            message(STATUS "[NASM] Download succeeded.")
            break()
        else()
            list(GET _download_status 1 _status_msg)
            message(STATUS "[NASM] Failed (code=${_status_code}): ${_status_msg}")
            file(REMOVE "${_nasm_zip}")
        endif()
    endforeach()

    if (NOT _download_ok)
        message(FATAL_ERROR
            "[NASM] All download URLs failed for NASM ${NASM_VERSION}.\n"
            "Manually download nasm-${NASM_VERSION}-win64.zip from https://www.nasm.us and\n"
            "extract it into ${_nasm_install_dir}, or check the NASM_VERSION variable."
        )
    endif()

    message(STATUS "[NASM] Extracting to ${_nasm_install_dir}...")
    file(MAKE_DIRECTORY "${_nasm_install_dir}")
    # file(ARCHIVE_EXTRACT) is CMake 3.18+ only -> use cmake -E tar for 3.15 compatibility
    # (it is libarchive-based, so it auto-detects zip from the extension)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E tar xf "${_nasm_zip}"
        WORKING_DIRECTORY "${_nasm_install_dir}"
        RESULT_VARIABLE _extract_result
    )
    if (NOT _extract_result EQUAL 0)
        file(REMOVE "${_nasm_zip}")
        message(FATAL_ERROR "[NASM] zip extraction failed (exit=${_extract_result}): ${_nasm_zip}")
    endif()
    file(REMOVE "${_nasm_zip}")

    file(GLOB_RECURSE _nasm_exe_candidates "${_nasm_install_dir}/nasm.exe")
    if (NOT _nasm_exe_candidates)
        message(FATAL_ERROR
            "[NASM] nasm.exe not found after extraction.\n"
            "Install dir: ${_nasm_install_dir}"
        )
    endif()

    message(STATUS "[NASM] Installation complete.")
else()
    message(STATUS "[NASM] Already installed, skipping download.")
endif()

list(GET _nasm_exe_candidates 0 NASM_EXECUTABLE)
get_filename_component(NASM_BIN_DIR "${NASM_EXECUTABLE}" DIRECTORY)

message(STATUS "[NASM] Executable : ${NASM_EXECUTABLE}")
message(STATUS "[NASM] Bin dir    : ${NASM_BIN_DIR}")