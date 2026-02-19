# cmake/acquire_perl/mingw.cmake
# MSYS2를 다운로드하고 pacman으로 Perl을 설치 (MinGW 빌드 전용)
#
# 출력 변수:
#   PERL_EXECUTABLE - perl.exe 전체 경로
#   PERL_BIN_DIR    - perl.exe 가 있는 디렉토리
#
# 동작 순서:
#   1. tools/msys2/msys64/usr/bin/perl.exe 가 이미 있으면 스킵
#   2. tools/msys2/msys64/usr/bin/bash.exe 가 없으면 MSYS2 base 다운로드 + 압축 해제
#   3. bash -l 을 통해 pacman.conf SigLevel = Never 설정 후 perl 설치

set(_msys2_install_dir "${CMAKE_CURRENT_SOURCE_DIR}/tools/msys2")
set(_msys2_root        "${_msys2_install_dir}/msys64")
set(_msys2_bash        "${_msys2_root}/usr/bin/bash.exe")
set(_msys2_perl_exe    "${_msys2_root}/usr/bin/perl.exe")

file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/tools")

# ─────────────────────────────────────────────────────────────────────────────
# 단계 1: MSYS2 base 다운로드 + 압축 해제 (bash.exe 가 없을 때만)
# ─────────────────────────────────────────────────────────────────────────────
if (NOT EXISTS "${_msys2_bash}")
    set(_msys2_tarball "${CMAKE_CURRENT_SOURCE_DIR}/tools/msys2-base.tar.xz")

    set(_msys2_urls
        "https://repo.msys2.org/distrib/msys2-base-x86_64-latest.tar.xz"
        "https://github.com/msys2/msys2-installer/releases/download/nightly-x86_64/msys2-base-x86_64-latest.tar.xz"
    )

    set(_download_ok FALSE)
    foreach(_url ${_msys2_urls})
        message(STATUS "[Perl/MSYS2] Trying: ${_url}")
        file(DOWNLOAD
            "${_url}"
            "${_msys2_tarball}"
            STATUS        _download_status
            TIMEOUT       300
            SHOW_PROGRESS
        )
        list(GET _download_status 0 _status_code)
        if (_status_code EQUAL 0)
            set(_download_ok TRUE)
            message(STATUS "[Perl/MSYS2] Download succeeded.")
            break()
        else()
            list(GET _download_status 1 _status_msg)
            message(STATUS "[Perl/MSYS2] Failed (code=${_status_code}): ${_status_msg}")
            file(REMOVE "${_msys2_tarball}")
        endif()
    endforeach()

    if (NOT _download_ok)
        message(FATAL_ERROR
            "[Perl/MSYS2] All download URLs failed.\n"
            "수동으로 https://www.msys2.org 에서 MSYS2를 설치한 뒤\n"
            "${_msys2_install_dir} 아래에 msys64 디렉토리를 두거나\n"
            "pacman -S perl 을 직접 실행하세요."
        )
    endif()

    message(STATUS "[Perl/MSYS2] Extracting to ${_msys2_install_dir}...")
    file(MAKE_DIRECTORY "${_msys2_install_dir}")
    file(ARCHIVE_EXTRACT
        INPUT       "${_msys2_tarball}"
        DESTINATION "${_msys2_install_dir}"
    )
    file(REMOVE "${_msys2_tarball}")

    if (NOT EXISTS "${_msys2_bash}")
        message(FATAL_ERROR
            "[Perl/MSYS2] bash.exe not found after extraction.\n"
            "Expected: ${_msys2_bash}"
        )
    endif()

    message(STATUS "[Perl/MSYS2] MSYS2 base extraction complete.")
else()
    message(STATUS "[Perl/MSYS2] MSYS2 already extracted, skipping download.")
endif()

# ─────────────────────────────────────────────────────────────────────────────
# 단계 2: pacman 으로 perl 설치 (perl.exe 가 없을 때만)
#
# 자동화 빌드에서 keyring 초기화 없이 pacman 을 실행하기 위해:
#   - pacman.conf 의 SigLevel 을 Never 로 변경
#   - pacman -Sy --noconfirm perl
# ─────────────────────────────────────────────────────────────────────────────
if (NOT EXISTS "${_msys2_perl_exe}")
    message(STATUS "[Perl/MSYS2] Installing perl via pacman...")

    execute_process(
        COMMAND "${_msys2_bash}" -l -c
            "sed -i 's/^SigLevel.*/SigLevel = Never/' /etc/pacman.conf \
             && pacman --noconfirm --noprogressbar -Sy perl 2>&1"
        RESULT_VARIABLE _pacman_result
        TIMEOUT         300
        ECHO_OUTPUT_VARIABLE
        ECHO_ERROR_VARIABLE
    )

    if (NOT _pacman_result EQUAL 0)
        message(FATAL_ERROR
            "[Perl/MSYS2] pacman perl 설치 실패 (exit=${_pacman_result})\n"
            "인터넷 연결을 확인하거나 MSYS2 셸에서 'pacman -S perl' 을 수동 실행하세요."
        )
    endif()

    message(STATUS "[Perl/MSYS2] Perl installation complete.")
else()
    message(STATUS "[Perl/MSYS2] Perl already installed, skipping pacman.")
endif()

# ─────────────────────────────────────────────────────────────────────────────
# 출력 변수 설정
# ─────────────────────────────────────────────────────────────────────────────
if (NOT EXISTS "${_msys2_perl_exe}")
    message(FATAL_ERROR
        "[Perl/MSYS2] perl.exe not found after installation.\n"
        "Expected: ${_msys2_perl_exe}"
    )
endif()

set(PERL_EXECUTABLE "${_msys2_perl_exe}")
get_filename_component(PERL_BIN_DIR "${PERL_EXECUTABLE}" DIRECTORY)

message(STATUS "[Perl/MSYS2] Executable : ${PERL_EXECUTABLE}")
message(STATUS "[Perl/MSYS2] Bin dir    : ${PERL_BIN_DIR}")
