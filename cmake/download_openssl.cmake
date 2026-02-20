# cmake/download_openssl.cmake
# OpenSSL 소스 코드를 external/openssl 에 다운로드/압축해제한다.
#
# 필요 변수:
#   OPENSSL_VERSION - 다운로드할 OpenSSL 버전 (예: 3.6.1)
#
# 출력 변수:
#   openssl_SOURCE_DIR - OpenSSL 소스 디렉토리 전체 경로
#                        → ${CMAKE_CURRENT_SOURCE_DIR}/external/openssl

set(_openssl_src_dir  "${CMAKE_CURRENT_SOURCE_DIR}/external/openssl")
set(_openssl_tarball  "${CMAKE_CURRENT_SOURCE_DIR}/external/openssl-${OPENSSL_VERSION}.tar.gz")

file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/external")

# Configure 스크립트 존재 여부로 이미 다운로드됐는지 판단
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
            "[OpenSSL] 모든 다운로드 URL 실패.\n"
            "수동으로 OpenSSL ${OPENSSL_VERSION} 소스를\n"
            "  ${_openssl_src_dir}\n"
            "에 압축 해제하세요."
        )
    endif()

    # 압축 해제: tarball 안의 최상위 디렉토리는 openssl-${OPENSSL_VERSION}/
    message(STATUS "[OpenSSL] Extracting to ${CMAKE_CURRENT_SOURCE_DIR}/external/ ...")
    file(ARCHIVE_EXTRACT
        INPUT       "${_openssl_tarball}"
        DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/external"
    )
    file(REMOVE "${_openssl_tarball}")

    # openssl-3.6.1/ → openssl/ 로 이름 변경
    set(_extracted_dir "${CMAKE_CURRENT_SOURCE_DIR}/external/openssl-${OPENSSL_VERSION}")
    if (EXISTS "${_extracted_dir}" AND NOT EXISTS "${_openssl_src_dir}/Configure")
        file(RENAME "${_extracted_dir}" "${_openssl_src_dir}")
    endif()

    if (NOT EXISTS "${_openssl_src_dir}/Configure")
        message(FATAL_ERROR
            "[OpenSSL] Configure 스크립트를 찾을 수 없습니다.\n"
            "예상 경로: ${_openssl_src_dir}/Configure"
        )
    endif()

    message(STATUS "[OpenSSL] Source extraction complete.")

else()
    message(STATUS "[OpenSSL] Already downloaded, skipping.")
endif()

set(openssl_SOURCE_DIR "${_openssl_src_dir}")
message(STATUS "[OpenSSL] Source dir : ${openssl_SOURCE_DIR}")
