# cmake/acquire_perl/android.cmake
# Android 크로스컴파일 호스트용 Perl 탐색
#
# Android 크로스컴파일은 호스트(빌드 머신)에서 Configure를 실행하므로,
# 호스트 시스템에 맞는 Perl을 획득한다.
#
#   Windows  → mingw.cmake 와 동일하게 MSYS2 환경 사용
#              (MSYS2 bash 내에서 perl을 실행해야 NDK의 .cmd 크로스컴파일러가
#               확장자 없이 노출되어 OpenSSL Configure의 -f 체크를 통과함)
#   Linux    → 시스템 Perl (find_program)
#   macOS    → 시스템 Perl (find_program)
#
# 출력 변수:
#   PERL_EXECUTABLE - perl 실행 파일 전체 경로
#   PERL_BIN_DIR    - perl 실행 파일이 위치한 디렉토리

if (CMAKE_HOST_WIN32)
    # -------------------------------------------------------------------------
    # Windows 호스트: MSYS2 환경 사용 (bash + perl 포함)
    #
    # 이유: NDK R25+ Windows에서 크로스컴파일러는 .cmd 래퍼로만 제공된다.
    #       15-android.conf는 which("clang")으로 컴파일러를 탐색하는데,
    #       MSYS2 bash 내에서 실행해야 POSIX 레이어가 .cmd를 확장자 없이 노출하여
    #       which()가 컴파일러를 찾고 경로 정규식 매칭도 성공한다.
    #
    # Configure와 make 모두 MSYS2 bash 안에서 실행한다:
    #   - Configure: MSYS2 perl + cygpath으로 경로 변환
    #   - make: NDK prebuilt make.exe를 MSYS2 bash 내에서 호출
    #           (NDK make는 MSYS2 런타임으로 빌드되어 POSIX 경로를 이해함)
    # -------------------------------------------------------------------------
    include(cmake/acquire_perl/mingw.cmake)

else()
    # -------------------------------------------------------------------------
    # Linux / macOS 호스트: 시스템에 설치된 Perl 탐색
    # -------------------------------------------------------------------------
    find_program(PERL_EXECUTABLE
        NAMES perl perl5
        DOC "Perl interpreter (Android build host)"
    )

    if (NOT PERL_EXECUTABLE)
        message(FATAL_ERROR
            "[Perl] Android 빌드에서 Perl을 찾을 수 없습니다.\n"
            "호스트 시스템에 Perl을 설치하세요:\n"
            "  Linux : sudo apt install perl\n"
            "  macOS : brew install perl"
        )
    endif()

    get_filename_component(PERL_BIN_DIR "${PERL_EXECUTABLE}" DIRECTORY)
    message(STATUS "[Perl] Perl executable : ${PERL_EXECUTABLE}")
    message(STATUS "[Perl] Perl bin dir    : ${PERL_BIN_DIR}")

endif()
