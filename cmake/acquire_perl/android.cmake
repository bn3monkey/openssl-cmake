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
    # 이유: OpenSSL의 15-android.conf가 크로스컴파일러를 Perl -f 연산자로
    #       풀 경로 체크하는데, NDK R25+ Windows는 .cmd 파일만 제공한다.
    #       MSYS2 bash 안에서 perl을 실행해야 MSYS2 POSIX 레이어가
    #       .cmd 파일을 확장자 없이 노출시켜 -f 체크를 통과시킨다.
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
