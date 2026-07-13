# cmake/acquire_perl/linux.cmake
# Finds the system Perl on a Linux host
#
# Output variables:
#   PERL_EXECUTABLE - Full path to the perl executable
#   PERL_BIN_DIR    - Directory containing the perl executable

find_program(PERL_EXECUTABLE
    NAMES perl perl5
    DOC "Perl interpreter (Linux system)"
)

if (NOT PERL_EXECUTABLE)
    message(FATAL_ERROR
        "[Perl] Perl could not be found for the Linux build.\n"
        "Install it with your package manager:\n"
        "  Ubuntu/Debian : sudo apt install perl\n"
        "  Fedora/RHEL   : sudo dnf install perl\n"
        "  Arch          : sudo pacman -S perl"
    )
endif()

get_filename_component(PERL_BIN_DIR "${PERL_EXECUTABLE}" DIRECTORY)
message(STATUS "[Perl] Perl executable : ${PERL_EXECUTABLE}")
message(STATUS "[Perl] Perl bin dir    : ${PERL_BIN_DIR}")
