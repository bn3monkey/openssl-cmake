# cmake/acquire_perl/msvc.cmake
# Strawberry Perl (portable) 다운로드 및 설치
#
# 설정 가능 변수:
#   STRAWBERRY_PERL_VERSION     - Perl 버전 (기본값: 5.42.0.1)
#   STRAWBERRY_PERL_RELEASE_TAG - GitHub 릴리즈 태그 (기본값: SP_54201_64bit)
#
# 출력 변수:
#   PERL_EXECUTABLE - perl.exe 전체 경로
#   PERL_BIN_DIR    - perl.exe 가 있는 디렉토리

if (NOT DEFINED STRAWBERRY_PERL_VERSION)
    set(STRAWBERRY_PERL_VERSION "5.42.0.1")
endif()

if (NOT DEFINED STRAWBERRY_PERL_RELEASE_TAG)
    set(STRAWBERRY_PERL_RELEASE_TAG "SP_54201_64bit")
endif()

set(_perl_install_dir "${CMAKE_CURRENT_SOURCE_DIR}/tools/perl")
set(_perl_zip         "${CMAKE_CURRENT_SOURCE_DIR}/tools/strawberry-perl.zip")

# tools 디렉토리 생성
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/tools")

# 이미 설치된 경우 검색만 수행
file(GLOB_RECURSE _perl_exe_candidates "${_perl_install_dir}/perl.exe")

if (NOT _perl_exe_candidates)
    set(_perl_url
        "https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/${STRAWBERRY_PERL_RELEASE_TAG}/strawberry-perl-${STRAWBERRY_PERL_VERSION}-64bit-portable.zip"
    )

    message(STATUS "[Perl] Downloading Strawberry Perl ${STRAWBERRY_PERL_VERSION}...")
    message(STATUS "[Perl] URL: ${_perl_url}")

    file(DOWNLOAD
        "${_perl_url}"
        "${_perl_zip}"
        SHOW_PROGRESS
        STATUS   _download_status
        TIMEOUT  300
    )

    list(GET _download_status 0 _status_code)
    if (NOT _status_code EQUAL 0)
        list(GET _download_status 1 _status_msg)
        message(FATAL_ERROR
            "[Perl] Download failed (code=${_status_code}): ${_status_msg}\n"
            "URL: ${_perl_url}"
        )
    endif()

    message(STATUS "[Perl] Extracting to ${_perl_install_dir}...")
    file(MAKE_DIRECTORY "${_perl_install_dir}")
    file(ARCHIVE_EXTRACT
        INPUT       "${_perl_zip}"
        DESTINATION "${_perl_install_dir}"
    )
    file(REMOVE "${_perl_zip}")

    file(GLOB_RECURSE _perl_exe_candidates "${_perl_install_dir}/perl.exe")
    if (NOT _perl_exe_candidates)
        message(FATAL_ERROR
            "[Perl] perl.exe not found after extraction.\n"
            "Install dir: ${_perl_install_dir}"
        )
    endif()

    message(STATUS "[Perl] Installation complete.")
else()
    message(STATUS "[Perl] Already installed, skipping download.")
endif()

# perl.exe 경로 중 site/bin 이 아닌 메인 perl.exe 선택
set(_perl_exe "")
foreach(_candidate ${_perl_exe_candidates})
    if (NOT _candidate MATCHES "site[/\\\\]bin")
        set(_perl_exe "${_candidate}")
        break()
    endif()
endforeach()

if (NOT _perl_exe)
    list(GET _perl_exe_candidates 0 _perl_exe)
endif()

get_filename_component(PERL_BIN_DIR "${_perl_exe}" DIRECTORY)
set(PERL_EXECUTABLE "${_perl_exe}")

message(STATUS "[Perl] Executable : ${PERL_EXECUTABLE}")
message(STATUS "[Perl] Bin dir    : ${PERL_BIN_DIR}")
