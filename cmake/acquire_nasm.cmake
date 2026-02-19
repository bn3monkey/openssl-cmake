# cmake/acquire_nasm.cmake
# NASM (Netwide Assembler) 다운로드 및 설치 (Windows 전용)
#
# 설정 가능 변수:
#   NASM_VERSION - NASM 버전 (기본값: 3.01)
#
# 출력 변수:
#   NASM_EXECUTABLE - nasm.exe 전체 경로
#   NASM_BIN_DIR    - nasm.exe 가 있는 디렉토리
#
# 다운로드 URL 우선순위:
#   1. https://www.nasm.us/pub/nasm/releasebuilds/...
#   2. https://www.nasm.dev/pub/nasm/releasebuilds/...
#   3. https://vcpkg.github.io/assets/nasm/...

if (NOT DEFINED NASM_VERSION)
    set(NASM_VERSION "3.01")
endif()

set(_nasm_install_dir "${CMAKE_CURRENT_SOURCE_DIR}/tools/nasm")
set(_nasm_zip         "${CMAKE_CURRENT_SOURCE_DIR}/tools/nasm.zip")

# tools 디렉토리 생성
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/tools")

# 이미 설치된 경우 검색만 수행
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
            "수동으로 https://www.nasm.us 에서 nasm-${NASM_VERSION}-win64.zip 을 받아\n"
            "${_nasm_install_dir} 에 압축 해제하거나, NASM_VERSION 변수를 확인하세요."
        )
    endif()

    message(STATUS "[NASM] Extracting to ${_nasm_install_dir}...")
    file(MAKE_DIRECTORY "${_nasm_install_dir}")
    file(ARCHIVE_EXTRACT
        INPUT       "${_nasm_zip}"
        DESTINATION "${_nasm_install_dir}"
    )
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