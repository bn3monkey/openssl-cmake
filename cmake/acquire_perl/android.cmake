# cmake/acquire_perl/android.cmake
# Finds Perl for the Android cross-compilation host
#
# Android cross-compilation runs Configure on the host (build machine),
# so we acquire a Perl that matches the host system.
#
#   Windows  -> Use the MSYS2 environment, same as mingw.cmake
#               (perl must run inside MSYS2 bash so the NDK's .cmd cross-compilers
#                are exposed without an extension and pass OpenSSL Configure's -f check)
#   Linux    -> System Perl (find_program)
#   macOS    -> System Perl (find_program)
#
# Output variables:
#   PERL_EXECUTABLE - Full path to the perl executable
#   PERL_BIN_DIR    - Directory containing the perl executable

if (CMAKE_HOST_WIN32)
    # -------------------------------------------------------------------------
    # Windows host: use the MSYS2 environment (includes bash + perl)
    #
    # Reason: on NDK R25+ for Windows, the cross-compilers ship only as .cmd wrappers.
    #         15-android.conf looks the compiler up with which("clang"), so it must run
    #         inside MSYS2 bash, where the POSIX layer exposes the .cmd files without an
    #         extension, letting which() find the compiler and the path regex match too.
    #
    # Both Configure and make are run inside MSYS2 bash:
    #   - Configure: MSYS2 perl + cygpath for path conversion
    #   - make: invoke the NDK prebuilt make.exe from inside MSYS2 bash
    #           (the NDK make is built against the MSYS2 runtime, so it understands POSIX paths)
    # -------------------------------------------------------------------------
    include(cmake/acquire_perl/mingw.cmake)

else()
    # -------------------------------------------------------------------------
    # Linux / macOS host: find the Perl installed on the system
    # -------------------------------------------------------------------------
    find_program(PERL_EXECUTABLE
        NAMES perl perl5
        DOC "Perl interpreter (Android build host)"
    )

    if (NOT PERL_EXECUTABLE)
        message(FATAL_ERROR
            "[Perl] Perl could not be found for the Android build.\n"
            "Install Perl on the host system:\n"
            "  Linux : sudo apt install perl\n"
            "  macOS : brew install perl"
        )
    endif()

    get_filename_component(PERL_BIN_DIR "${PERL_EXECUTABLE}" DIRECTORY)
    message(STATUS "[Perl] Perl executable : ${PERL_EXECUTABLE}")
    message(STATUS "[Perl] Perl bin dir    : ${PERL_BIN_DIR}")

endif()
