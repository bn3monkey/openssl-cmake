# cmake/acquire_jom.cmake
# JOM (Qt의 병렬 nmake 대체재) 다운로드 및 설치 (Windows 전용)
#
# 설정 가능 변수:
#   JOM_VERSION - JOM 버전 (기본값: 1_1_4)
#
# 출력 변수:
#   JOM_EXECUTABLE - jom.exe 전체 경로
#   JOM_BIN_DIR    - jom.exe 가 있는 디렉토리
#
# 다운로드 URL:
#   https://download.qt.io/official_releases/jom/jom_<version>.zip

if (NOT DEFINED JOM_VERSION)
    set(JOM_VERSION "1_1_4")
endif()

set(_jom_install_dir "${CMAKE_CURRENT_SOURCE_DIR}/tools/jom")
set(_jom_zip         "${CMAKE_CURRENT_SOURCE_DIR}/tools/jom.zip")

# tools 디렉토리 생성
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/tools")

# 이미 설치된 경우 검색만 수행
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
            "수동으로 https://download.qt.io/official_releases/jom/ 에서 jom_${JOM_VERSION}.zip 을 받아\n"
            "${_jom_install_dir} 에 압축 해제하거나, JOM_VERSION 변수를 확인하세요."
        )
    endif()

    message(STATUS "[JOM] Extracting to ${_jom_install_dir}...")
    file(MAKE_DIRECTORY "${_jom_install_dir}")
    file(ARCHIVE_EXTRACT
        INPUT       "${_jom_zip}"
        DESTINATION "${_jom_install_dir}"
    )
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
