# cmake/acquire_perl.cmake
# Acquires a Perl interpreter appropriate for the build environment.
#
# Required variables:
#   TARGET_OS       - Target OS (Windows, Linux, Android)
#   TARGET_COMPILER - Target compiler (msvc, mingw, gcc, clang)
#
# Output variables (set by the per-platform cmake files):
#   PERL_EXECUTABLE - Full path to the perl executable
#   PERL_BIN_DIR    - Directory containing the perl executable

if ("${TARGET_OS}" STREQUAL "Windows")
    if ("${TARGET_COMPILER}" STREQUAL "msvc")
        # MSVC: download portable Strawberry Perl
        include(cmake/acquire_perl/msvc.cmake)
    elseif ("${TARGET_COMPILER}" STREQUAL "mingw")
        # MinGW: install MSYS2, then acquire Perl via pacman
        include(cmake/acquire_perl/mingw.cmake)
    else()
        message(FATAL_ERROR "[Perl] Unsupported Windows compiler: ${TARGET_COMPILER}")
    endif()

elseif ("${TARGET_OS}" STREQUAL "Linux")
    include(cmake/acquire_perl/linux.cmake)

elseif ("${TARGET_OS}" STREQUAL "Android")
    include(cmake/acquire_perl/android.cmake)

else()
    message(FATAL_ERROR "[Perl] Unsupported TARGET_OS: ${TARGET_OS}")
endif()

if (NOT PERL_EXECUTABLE)
    message(FATAL_ERROR "[Perl] PERL_EXECUTABLE is not set after include.")
endif()
