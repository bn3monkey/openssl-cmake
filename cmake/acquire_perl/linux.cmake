# cmake/acquire_perl/linux.cmake
# Linux 호스트용 시스템 Perl 탐색
#
# 출력 변수:
#   PERL_EXECUTABLE - perl 실행 파일 전체 경로
#   PERL_BIN_DIR    - perl 실행 파일이 위치한 디렉토리

find_program(PERL_EXECUTABLE
    NAMES perl perl5
    DOC "Perl interpreter (Linux system)"
)

if (NOT PERL_EXECUTABLE)
    message(FATAL_ERROR
        "[Perl] Linux 빌드에서 Perl을 찾을 수 없습니다.\n"
        "패키지 매니저로 설치하세요:\n"
        "  Ubuntu/Debian : sudo apt install perl\n"
        "  Fedora/RHEL   : sudo dnf install perl\n"
        "  Arch          : sudo pacman -S perl"
    )
endif()

get_filename_component(PERL_BIN_DIR "${PERL_EXECUTABLE}" DIRECTORY)
message(STATUS "[Perl] Perl executable : ${PERL_EXECUTABLE}")
message(STATUS "[Perl] Perl bin dir    : ${PERL_BIN_DIR}")
