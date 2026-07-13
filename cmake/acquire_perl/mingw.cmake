# cmake/acquire_perl/mingw.cmake
# Downloads MSYS2 and installs Perl via pacman (MinGW builds only)
#
# Output variables:
#   PERL_EXECUTABLE - Full path to perl.exe
#   PERL_BIN_DIR    - Directory containing perl.exe
#
# Sequence of operations:
#   1. Skip if tools/msys2/msys64/usr/bin/perl.exe already exists
#   2. If tools/msys2/msys64/usr/bin/bash.exe is missing, download and extract the MSYS2 base
#   3. Via bash -l, set SigLevel = Never in pacman.conf, then install perl

set(_msys2_install_dir "${CMAKE_CURRENT_SOURCE_DIR}/tools/msys2")
set(_msys2_root        "${_msys2_install_dir}/msys64")
set(_msys2_bash        "${_msys2_root}/usr/bin/bash.exe")
set(_msys2_perl_exe    "${_msys2_root}/usr/bin/perl.exe")

file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/tools")

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Download and extract the MSYS2 base (only when bash.exe is missing)
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
            "Install MSYS2 manually from https://www.msys2.org, then either\n"
            "place the msys64 directory under ${_msys2_install_dir}\n"
            "or run 'pacman -S perl' yourself."
        )
    endif()

    message(STATUS "[Perl/MSYS2] Extracting to ${_msys2_install_dir}...")
    file(MAKE_DIRECTORY "${_msys2_install_dir}")
    # file(ARCHIVE_EXTRACT) is CMake 3.18+ only -> use cmake -E tar for 3.15 compatibility
    # (it is libarchive-based, so it auto-detects .tar.xz compression)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E tar xf "${_msys2_tarball}"
        WORKING_DIRECTORY "${_msys2_install_dir}"
        RESULT_VARIABLE _extract_result
    )
    if (NOT _extract_result EQUAL 0)
        file(REMOVE "${_msys2_tarball}")
        message(FATAL_ERROR "[Perl/MSYS2] tar.xz extraction failed (exit=${_extract_result}): ${_msys2_tarball}")
    endif()
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
# Step 2: Install perl via pacman (only when perl.exe is missing)
#
# To run pacman without initializing the keyring in an automated build:
#   - Change SigLevel in pacman.conf to Never
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
        # ECHO_*_VARIABLE (3.18+) removed -> 3.15 compatibility.
        # OUTPUT_VARIABLE is not specified, so output is passed straight to the console (preserves the previous behavior).
    )

    if (NOT _pacman_result EQUAL 0)
        message(FATAL_ERROR
            "[Perl/MSYS2] pacman perl installation failed (exit=${_pacman_result})\n"
            "Check your internet connection, or run 'pacman -S perl' manually in an MSYS2 shell."
        )
    endif()

    message(STATUS "[Perl/MSYS2] Perl installation complete.")
else()
    message(STATUS "[Perl/MSYS2] Perl already installed, skipping pacman.")
endif()

# ─────────────────────────────────────────────────────────────────────────────
# Set output variables
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
