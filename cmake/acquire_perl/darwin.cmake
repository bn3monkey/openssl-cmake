# cmake/acquire_perl/darwin.cmake
# Finds the system Perl on a macOS host
#
# Output variables:
#   PERL_EXECUTABLE - Full path to the perl executable
#   PERL_BIN_DIR    - Directory containing the perl executable

find_program(PERL_EXECUTABLE
    NAMES perl perl5
    DOC "Perl interpreter (macOS system)"
)

if (NOT PERL_EXECUTABLE)
    message(FATAL_ERROR
        "[Perl] Perl could not be found for the macOS build.\n"
        "macOS ships Perl with the Xcode Command Line Tools:\n"
        "  xcode-select --install\n"
        "or install it with Homebrew:\n"
        "  brew install perl"
    )
endif()

get_filename_component(PERL_BIN_DIR "${PERL_EXECUTABLE}" DIRECTORY)
message(STATUS "[Perl] Perl executable : ${PERL_EXECUTABLE}")
message(STATUS "[Perl] Perl bin dir    : ${PERL_BIN_DIR}")
