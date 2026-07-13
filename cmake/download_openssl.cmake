# cmake/download_openssl.cmake
# Downloads and extracts the OpenSSL source code into external/openssl.
#
# Required variables:
#   OPENSSL_VERSION - the OpenSSL version to download (e.g. 3.6.1)
#
# Output variables:
#   openssl_SOURCE_DIR - full path to the OpenSSL source directory
#                        → ${CMAKE_CURRENT_SOURCE_DIR}/external/openssl

set(_openssl_src_dir  "${CMAKE_CURRENT_SOURCE_DIR}/external/openssl")
set(_openssl_tarball  "${CMAKE_CURRENT_SOURCE_DIR}/external/openssl-${OPENSSL_VERSION}.tar.gz")

file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/external")

# Use the presence of the Configure script to decide whether it has already been downloaded
if (NOT EXISTS "${_openssl_src_dir}/Configure")

    set(_openssl_urls
        "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"
        "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
    )

    set(_download_ok FALSE)
    foreach(_url ${_openssl_urls})
        message(STATUS "[OpenSSL] Trying: ${_url}")
        file(DOWNLOAD
            "${_url}"
            "${_openssl_tarball}"
            STATUS        _download_status
            TIMEOUT       300
            SHOW_PROGRESS
        )
        list(GET _download_status 0 _status_code)
        if (_status_code EQUAL 0)
            set(_download_ok TRUE)
            message(STATUS "[OpenSSL] Download succeeded.")
            break()
        else()
            list(GET _download_status 1 _status_msg)
            message(STATUS "[OpenSSL] Failed (code=${_status_code}): ${_status_msg}")
            file(REMOVE "${_openssl_tarball}")
        endif()
    endforeach()

    if (NOT _download_ok)
        message(FATAL_ERROR
            "[OpenSSL] All download URLs failed.\n"
            "Please manually extract the OpenSSL ${OPENSSL_VERSION} source\n"
            "  ${_openssl_src_dir}\n"
            "into the directory above."
        )
    endif()

    # Extraction: the top-level directory inside the tarball is openssl-${OPENSSL_VERSION}/
    #
    # file(ARCHIVE_EXTRACT) is only available in CMake 3.18+, but the minimum
    # required version of this project is 3.15, so it is replaced with
    # "cmake -E tar xzf" (execute_process), which works on all versions.
    message(STATUS "[OpenSSL] Extracting to ${CMAKE_CURRENT_SOURCE_DIR}/external/ ...")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E tar xzf "${_openssl_tarball}"
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/external"
        RESULT_VARIABLE _extract_result
    )
    if (NOT _extract_result EQUAL 0)
        file(REMOVE "${_openssl_tarball}")
        message(FATAL_ERROR
            "[OpenSSL] Failed to extract tarball (exit=${_extract_result}):\n"
            "  ${_openssl_tarball}"
        )
    endif()
    file(REMOVE "${_openssl_tarball}")

    # Rename openssl-3.6.1/ → openssl/
    set(_extracted_dir "${CMAKE_CURRENT_SOURCE_DIR}/external/openssl-${OPENSSL_VERSION}")
    if (EXISTS "${_extracted_dir}" AND NOT EXISTS "${_openssl_src_dir}/Configure")
        file(RENAME "${_extracted_dir}" "${_openssl_src_dir}")
    endif()

    if (NOT EXISTS "${_openssl_src_dir}/Configure")
        message(FATAL_ERROR
            "[OpenSSL] Could not find the Configure script.\n"
            "Expected path: ${_openssl_src_dir}/Configure"
        )
    endif()

    message(STATUS "[OpenSSL] Source extraction complete.")

else()
    message(STATUS "[OpenSSL] Already downloaded, skipping.")
endif()

set(openssl_SOURCE_DIR "${_openssl_src_dir}")
message(STATUS "[OpenSSL] Source dir : ${openssl_SOURCE_DIR}")
