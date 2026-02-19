# cmake/acquire_perl/android.cmake
# Android 크로스컴파일 호스트용 Perl 탐색
#
# Android 크로스컴파일은 호스트(빌드 머신)에서 Configure를 실행하므로,
# 호스트 시스템에 맞는 Perl을 획득한다.
#
#   Windows  → msvc.cmake 와 동일하게 Strawberry Perl 사용
#              (네이티브 Windows Perl → NDK .cmd 래퍼를 PATH에서 정상 탐색)
#   Linux    → 시스템 Perl (find_program)
#   macOS    → 시스템 Perl (find_program)
#
# 출력 변수:
#   PERL_EXECUTABLE - perl 실행 파일 전체 경로
#   PERL_BIN_DIR    - perl 실행 파일이 위치한 디렉토리

if (CMAKE_HOST_WIN32)
    # -------------------------------------------------------------------------
    # Windows 호스트: Strawberry Perl (네이티브 Windows)
    #   - cmd.exe 기반으로 실행 → NDK의 .cmd 래퍼를 PATH에서 정상 탐색
    #   - MSYS2 bash 없이 set(ENV{PATH}) 만으로 동작
    # -------------------------------------------------------------------------
    include(cmake/acquire_perl/msvc.cmake)

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
