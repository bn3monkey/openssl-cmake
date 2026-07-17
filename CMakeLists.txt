cmake_minimum_required(VERSION 3.15)

project(openssl-cmake C CXX)

enable_language(C)
enable_language(CXX)

# ===========================================================================
# CONFIGURATION DETECTION
# ===========================================================================
message(STATUS " == OpenSSL Build == ")

## TARGET ARCHITECTURE
include(cmake/detect_target_architecture.cmake)
detectTargetArchitecture(TARGET_ARCH)
message(STATUS "Target architecture : ${TARGET_ARCH}")

## TARGET OS
set(TARGET_OS ${CMAKE_SYSTEM_NAME})
message(STATUS "Target OS : ${TARGET_OS}")

## TARGET COMPILER
include(cmake/detect_target_compiler.cmake)
detectTargetCompiler("${TARGET_OS}" TARGET_COMPILER)
message(STATUS "Target Compiler : ${TARGET_COMPILER}")


set(OPENSSL_VERSION 3.6.1)

# openssl-cmake's own version. Used as the default prebuilt release tag.
set(OPENSSL_CMAKE_VERSION 1.2.0)


# ===========================================================================
# PREBUILT vs SOURCE BUILD
#
# ON  : Download and use the prebuilt static libraries published on the
#       GitHub Release (default). Build time ~0, tens of MB of disk.
# OFF : Download the source and build it ourselves.
#       Works on every architecture but is slow, and downloads the toolchain
#       (Perl/NASM/MSYS2 etc.) into the build directory.
#
# Either way the final artifacts are the same: OpenSSL::SSL / OpenSSL::Crypto
# ===========================================================================
option(OPENSSL_CMAKE_USE_PREBUILT
    "Download prebuilt OpenSSL static libraries instead of building from source"
    ON)

set(OPENSSL_CMAKE_PREBUILT_TAG "v${OPENSSL_CMAKE_VERSION}" CACHE STRING
    "GitHub release tag to fetch prebuilt OpenSSL binaries from")

set(OPENSSL_CMAKE_PREBUILT_URL "" CACHE STRING
    "Override base URL for prebuilt assets (internal mirror / offline)")

if (OPENSSL_CMAKE_USE_PREBUILT)

    message(STATUS "[OpenSSL] Mode : PREBUILT (tag ${OPENSSL_CMAKE_PREBUILT_TAG})")
    include(cmake/prebuilt/fetch_prebuilt.cmake)

else()

message(STATUS "[OpenSSL] Mode : SOURCE BUILD")

# ===========================================================================
# DOWNLOAD OPENSSL SOURCE
# ===========================================================================
# openssl_SOURCE_DIR → ${CMAKE_CURRENT_SOURCE_DIR}/external/openssl
include(cmake/download_openssl.cmake)

# openssl_BINARY_DIR : build output location (libcrypto.a, libssl.a, etc.)
#
# This MUST be a subdirectory, not CMAKE_CURRENT_BINARY_DIR itself.
# OpenSSL's Configure writes a "Makefile" into its build directory, and the
# Makefile-based generators ("Unix Makefiles", "MinGW Makefiles", ...) write
# their own "Makefile" into CMAKE_CURRENT_BINARY_DIR. CMake's generate step
# runs after our configure-time execute_process, so it would clobber OpenSSL's
# Makefile and the build would fail with "No rule to make target 'build_libs'".
set(openssl_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/openssl-build")

message(STATUS "OpenSSL source dir : ${openssl_SOURCE_DIR}")
message(STATUS "OpenSSL build dir  : ${openssl_BINARY_DIR}")


# ===========================================================================
# BUILD: Windows + MSVC
# ===========================================================================
if ("${TARGET_OS}" STREQUAL "Windows" AND "${TARGET_COMPILER}" STREQUAL "msvc")

    # -----------------------------------------------------------------------
    # Step 1. Acquire Perl
    # -----------------------------------------------------------------------
    include(cmake/acquire_perl.cmake)
    # → sets PERL_EXECUTABLE, PERL_BIN_DIR

    # -----------------------------------------------------------------------
    # Step 2. Acquire NASM
    # -----------------------------------------------------------------------
    include(cmake/acquire_nasm.cmake)
    # → sets NASM_EXECUTABLE, NASM_BIN_DIR

    # -----------------------------------------------------------------------
    # Step 2-1. Acquire JOM (parallel nmake replacement)
    # -----------------------------------------------------------------------
    include(cmake/acquire_jom.cmake)
    # → sets JOM_EXECUTABLE, JOM_BIN_DIR

    # -----------------------------------------------------------------------
    # Step 3. Prepend the Perl/NASM paths to the current CMake process's PATH
    #         (used by configure-time execute_process)
    # -----------------------------------------------------------------------
    set(ENV{PATH} "${PERL_BIN_DIR};${NASM_BIN_DIR};$ENV{PATH}")
    message(STATUS "[OpenSSL] PATH prepended with Perl and NASM bin dirs.")

    # -----------------------------------------------------------------------
    # Step 4. Determine the OpenSSL configure target per architecture
    # -----------------------------------------------------------------------
    if ("${TARGET_ARCH}" STREQUAL "x86")
        # 32-bit x86
        set(_openssl_configure_target "VC-WIN32")

    elseif ("${TARGET_ARCH}" STREQUAL "x64")
        # 64-bit x86_64
        set(_openssl_configure_target "VC-WIN64A")

    elseif ("${TARGET_ARCH}" STREQUAL "arm64")
        # Windows on ARM 64-bit
        set(_openssl_configure_target "VC-WIN64-ARM")

    elseif ("${TARGET_ARCH}" STREQUAL "amd")
        # AMD64 = same as x86_64 (OpenSSL does not provide a separate AMD target)
        set(_openssl_configure_target "VC-WIN64A")

    else()
        message(FATAL_ERROR
            "[OpenSSL] Unsupported architecture for the MSVC build: ${TARGET_ARCH}\n"
            "Supported: x86, x64, arm64, amd"
        )
    endif()
    message(STATUS "[OpenSSL] Configure target : ${_openssl_configure_target}")

    # -----------------------------------------------------------------------
    # Determine the build type (include debug symbols in Debug mode)
    #
    # When the --debug flag is enabled, OpenSSL applies the following:
    #   - Compiler flags: /Zi (generate PDB), /Od (optimization off), /RTC1 (runtime checks)
    #   - Debug CRT link: /MDd
    #   - Output: libcrypto.pdb, libssl.pdb (symbols traceable in Visual Studio)
    # -----------------------------------------------------------------------
    string(TOLOWER "${CMAKE_BUILD_TYPE}" _build_type_lower)
    if (_build_type_lower STREQUAL "debug")
        set(_openssl_debug_flags "--debug")
        message(STATUS "[OpenSSL] Build type : Debug (debug symbols ON  → /Zi /Od /MDd)")
    else()
        set(_openssl_debug_flags "")
        message(STATUS "[OpenSSL] Build type : ${CMAKE_BUILD_TYPE} (debug symbols OFF → /O2 /MD)")
    endif()

    # -----------------------------------------------------------------------
    # Run perl Configure (at CMake configure-time, on every run)
    #
    # Out-of-source build:
    #   source : openssl_SOURCE_DIR  (_deps/openssl-src)
    #   output : openssl_BINARY_DIR  (_deps/openssl-build)
    # -----------------------------------------------------------------------
    file(MAKE_DIRECTORY "${openssl_BINARY_DIR}")

    message(STATUS "[OpenSSL] Running: perl Configure ${_openssl_configure_target} ${_openssl_debug_flags}")
    message(STATUS "[OpenSSL]   source : ${openssl_SOURCE_DIR}")
    message(STATUS "[OpenSSL]   build  : ${openssl_BINARY_DIR}")

    execute_process(
        COMMAND
            "${PERL_EXECUTABLE}" "${openssl_SOURCE_DIR}/Configure"
            "${_openssl_configure_target}"
            ${_openssl_debug_flags}    # Debug: --debug / Release: (none)
            no-shared                  # build static libraries only
            no-makedepend              # speeds up the build
        WORKING_DIRECTORY "${openssl_BINARY_DIR}"
        RESULT_VARIABLE   _configure_result
        OUTPUT_VARIABLE   _configure_output
        ERROR_VARIABLE    _configure_error
    )
    # Dropped ECHO_*_VARIABLE (3.18+) → 3.15 compatible. Print the captured output afterwards.
    message(STATUS "${_configure_output}")

    if (NOT _configure_result EQUAL 0)
        message(FATAL_ERROR
            "[OpenSSL] perl Configure failed (exit=${_configure_result}):\n"
            "${_configure_error}"
        )
    endif()

    message(STATUS "[OpenSSL] Configure done.")

    # -----------------------------------------------------------------------
    # Step 5. jom build → create the OpenSSL::Crypto, OpenSSL::SSL targets
    #
    # Inject the Perl/NASM PATH with `cmake -E env`, then run jom directly.
    # jom is nmake-compatible and supports parallel builds (-j), so it is fast.
    #
    # ※ How to embed a semicolon (;) in PATH:
    #   In a CMake COMMAND list ';' is interpreted as an argument separator, so it
    #   cannot be written directly. Using the $<SEMICOLON> generator expression:
    #     - at configure time: it is not parsed as a CMake list separator
    #     - at generate  time: it expands to a literal ';' character
    # -----------------------------------------------------------------------
    # This is an out-of-source build, so the libraries and generated headers live in openssl_BINARY_DIR
    set(_openssl_crypto_lib "${openssl_BINARY_DIR}/libcrypto.lib")
    set(_openssl_ssl_lib    "${openssl_BINARY_DIR}/libssl.lib")
    # include: build directory (generated headers such as opensslconf.h) + source directory (original headers)
    set(_openssl_include
        "${openssl_BINARY_DIR}/include"
        "${openssl_SOURCE_DIR}/include"
    )

    # Number of parallel jobs: build in parallel with as many jobs as there are processors
    include(ProcessorCount)
    ProcessorCount(_cpu_count)
    if (_cpu_count EQUAL 0)
        set(_cpu_count 4)   # default when detection fails
    endif()
    message(STATUS "[OpenSSL] jom parallel jobs : ${_cpu_count}")

    # Custom command that runs jom directly
    # cmake -E env "PATH=<perl>;<nasm>;<existing PATH>" jom -j<N>
    # $<SEMICOLON> expands to ';' at generate-time and acts as the PATH separator
    add_custom_command(
        OUTPUT
            "${_openssl_crypto_lib}"
            "${_openssl_ssl_lib}"
        COMMAND ${CMAKE_COMMAND} -E env
            "PATH=${PERL_BIN_DIR}$<SEMICOLON>${NASM_BIN_DIR}$<SEMICOLON>$ENV{PATH}"
            "CL=/FS"
            "${JOM_EXECUTABLE}" -j${_cpu_count} build_libs
        WORKING_DIRECTORY "${openssl_BINARY_DIR}"
        COMMENT "[OpenSSL] Building OpenSSL with jom -j${_cpu_count} build_libs..."
        USES_TERMINAL   # Ninja console pool → attached directly to the terminal → real-time output
        VERBATIM
    )

    # Build target: added to ALL so it is always built
    add_custom_target(openssl_jom_build ALL
        DEPENDS
            "${_openssl_crypto_lib}"
            "${_openssl_ssl_lib}"
        COMMENT "[OpenSSL] Ensuring OpenSSL libraries are built."
    )

    # Set the PDB (symbol) file paths for Debug builds
    # PDBs produced by an OpenSSL --debug build: allows Step-Into debugging in Visual Studio
    if (_build_type_lower STREQUAL "debug")
        set(_openssl_crypto_pdb "${openssl_BINARY_DIR}/libcrypto.pdb")
        set(_openssl_ssl_pdb    "${openssl_BINARY_DIR}/libssl.pdb")
    else()
        set(_openssl_crypto_pdb "")
        set(_openssl_ssl_pdb    "")
    endif()

    # Create the IMPORTED static library targets
    add_library(openssl_crypto STATIC IMPORTED GLOBAL)
    set_target_properties(openssl_crypto PROPERTIES
        IMPORTED_LOCATION             "${_openssl_crypto_lib}"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
        INTERFACE_LINK_LIBRARIES      "ws2_32;crypt32"
    )
    if (_openssl_crypto_pdb)
        set_target_properties(openssl_crypto PROPERTIES
            IMPORTED_PDB "${_openssl_crypto_pdb}"
        )
    endif()
    add_dependencies(openssl_crypto openssl_jom_build)

    add_library(openssl_ssl STATIC IMPORTED GLOBAL)
    set_target_properties(openssl_ssl PROPERTIES
        IMPORTED_LOCATION             "${_openssl_ssl_lib}"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
        INTERFACE_LINK_LIBRARIES      "openssl_crypto"
    )
    if (_openssl_ssl_pdb)
        set_target_properties(openssl_ssl PROPERTIES
            IMPORTED_PDB "${_openssl_ssl_pdb}"
        )
    endif()
    add_dependencies(openssl_ssl openssl_jom_build)

    # Standard namespaced aliases (wrapped as INTERFACE IMPORTED)
    add_library(OpenSSL::Crypto INTERFACE IMPORTED GLOBAL)
    set_target_properties(OpenSSL::Crypto PROPERTIES
        INTERFACE_LINK_LIBRARIES      "openssl_crypto"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
    )

    add_library(OpenSSL::SSL INTERFACE IMPORTED GLOBAL)
    set_target_properties(OpenSSL::SSL PROPERTIES
        INTERFACE_LINK_LIBRARIES      "openssl_ssl;openssl_crypto"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
    )

    message(STATUS "[OpenSSL] MSVC build targets ready: OpenSSL::Crypto, OpenSSL::SSL (jom -j${_cpu_count})")
    if (_build_type_lower STREQUAL "debug")
        message(STATUS "[OpenSSL]   Debug symbols : ${openssl_BINARY_DIR}/libcrypto.pdb")
        message(STATUS "[OpenSSL]                   ${openssl_BINARY_DIR}/libssl.pdb")
    endif()
    message(STATUS "[OpenSSL]   Link with: target_link_libraries(<your_target> OpenSSL::SSL)")


# ===========================================================================
# BUILD: Windows + MinGW (MinGW bundled with Qt)
# ===========================================================================
elseif ("${TARGET_OS}" STREQUAL "Windows" AND "${TARGET_COMPILER}" STREQUAL "mingw")

    # -----------------------------------------------------------------------
    # Step 1. Acquire Perl (Strawberry Perl - reused just like for MSVC)
    # -----------------------------------------------------------------------
    include(cmake/acquire_perl.cmake)
    # → sets PERL_EXECUTABLE, PERL_BIN_DIR

    # -----------------------------------------------------------------------
    # Step 2. Acquire NASM
    # -----------------------------------------------------------------------
    include(cmake/acquire_nasm.cmake)
    # → sets NASM_EXECUTABLE, NASM_BIN_DIR

    # -----------------------------------------------------------------------
    # Step 3. Locate the Qt MinGW bin directory
    #         CMAKE_C_COMPILER → .../mingwXXXX_64/bin/gcc.exe
    # -----------------------------------------------------------------------
    get_filename_component(_mingw_bin_dir "${CMAKE_C_COMPILER}" DIRECTORY)
    message(STATUS "[OpenSSL] MinGW bin dir : ${_mingw_bin_dir}")

    # -----------------------------------------------------------------------
    # Step 4. Prepend the Perl/NASM/MinGW paths to the current CMake process's PATH
    #         (used by configure-time execute_process)
    # -----------------------------------------------------------------------
    set(ENV{PATH} "${PERL_BIN_DIR};${NASM_BIN_DIR};${_mingw_bin_dir};$ENV{PATH}")
    message(STATUS "[OpenSSL] PATH prepended with Perl, NASM, and MinGW bin dirs.")

    # -----------------------------------------------------------------------
    # Step 5. Determine the OpenSSL configure target per architecture
    # -----------------------------------------------------------------------
    if ("${TARGET_ARCH}" STREQUAL "x64")
        set(_openssl_configure_target "mingw64")
    elseif ("${TARGET_ARCH}" STREQUAL "x86")
        set(_openssl_configure_target "mingw")
    else()
        message(FATAL_ERROR
            "[OpenSSL] Unsupported architecture for the MinGW build: ${TARGET_ARCH}\n"
            "Supported: x86, x64"
        )
    endif()
    message(STATUS "[OpenSSL] Configure target : ${_openssl_configure_target}")

    # -----------------------------------------------------------------------
    # Determine the build type
    # -----------------------------------------------------------------------
    string(TOLOWER "${CMAKE_BUILD_TYPE}" _build_type_lower)
    if (_build_type_lower STREQUAL "debug")
        set(_openssl_debug_flags "--debug")
        message(STATUS "[OpenSSL] Build type : Debug (debug symbols ON)")
    else()
        set(_openssl_debug_flags "")
        message(STATUS "[OpenSSL] Build type : ${CMAKE_BUILD_TYPE} (debug symbols OFF)")
    endif()

    # -----------------------------------------------------------------------
    # Run perl Configure (at CMake configure-time, on every run)
    # -----------------------------------------------------------------------
    file(MAKE_DIRECTORY "${openssl_BINARY_DIR}")

    message(STATUS "[OpenSSL] Running: perl Configure ${_openssl_configure_target} ${_openssl_debug_flags}")
    message(STATUS "[OpenSSL]   source : ${openssl_SOURCE_DIR}")
    message(STATUS "[OpenSSL]   build  : ${openssl_BINARY_DIR}")

    execute_process(
        COMMAND
            "${PERL_EXECUTABLE}" "${openssl_SOURCE_DIR}/Configure"
            "${_openssl_configure_target}"
            ${_openssl_debug_flags}    # Debug: --debug / Release: (none)
            no-shared                  # build static libraries only
            no-makedepend              # speeds up the build
            # SIO_UDP_NETRESET: undefined in the old winsock2 headers bundled with Qt MinGW 8.1
            # (a constant added in Windows 10 SDK 10.0.19041+)
            # IOC_IN(0x80000000) | IOC_VENDOR(0x18000000) | 26(0x1A) = 0x9800001A
            -DSIO_UDP_NETRESET=0x9800001A
        WORKING_DIRECTORY "${openssl_BINARY_DIR}"
        RESULT_VARIABLE   _configure_result
        OUTPUT_VARIABLE   _configure_output
        ERROR_VARIABLE    _configure_error
    )
    # Dropped ECHO_*_VARIABLE (3.18+) → 3.15 compatible. Print the captured output afterwards.
    message(STATUS "${_configure_output}")

    if (NOT _configure_result EQUAL 0)
        message(FATAL_ERROR
            "[OpenSSL] perl Configure failed (exit=${_configure_result}):\n"
            "${_configure_error}"
        )
    endif()

    message(STATUS "[OpenSSL] Configure done.")

    # -----------------------------------------------------------------------
    # Step 6. mingw32-make build → create the OpenSSL::Crypto, OpenSSL::SSL targets
    #
    # MinGW static library output: libcrypto.a, libssl.a
    # -----------------------------------------------------------------------
    set(_openssl_crypto_lib "${openssl_BINARY_DIR}/libcrypto.a")
    set(_openssl_ssl_lib    "${openssl_BINARY_DIR}/libssl.a")
    set(_openssl_include
        "${openssl_BINARY_DIR}/include"
        "${openssl_SOURCE_DIR}/include"
    )

    # mingw32-make lives in the same bin directory as CMAKE_C_COMPILER
    find_program(_mingw32_make_exe mingw32-make
        HINTS "${_mingw_bin_dir}"
        NO_DEFAULT_PATH
    )
    if (NOT _mingw32_make_exe)
        message(FATAL_ERROR
            "[OpenSSL] Could not find mingw32-make.\n"
            "Check that the Qt MinGW toolchain is set up correctly.\n"
            "Searched path: ${_mingw_bin_dir}"
        )
    endif()
    message(STATUS "[OpenSSL] mingw32-make : ${_mingw32_make_exe}")

    include(ProcessorCount)
    ProcessorCount(_cpu_count)
    if (_cpu_count EQUAL 0)
        set(_cpu_count 4)
    endif()
    message(STATUS "[OpenSSL] mingw32-make parallel jobs : ${_cpu_count}")

    add_custom_command(
        OUTPUT
            "${_openssl_crypto_lib}"
            "${_openssl_ssl_lib}"
        COMMAND ${CMAKE_COMMAND} -E env
            "PATH=${PERL_BIN_DIR}$<SEMICOLON>${NASM_BIN_DIR}$<SEMICOLON>${_mingw_bin_dir}$<SEMICOLON>$ENV{PATH}"
            "${_mingw32_make_exe}" -j${_cpu_count} build_libs
        WORKING_DIRECTORY "${openssl_BINARY_DIR}"
        COMMENT "[OpenSSL] Building OpenSSL with mingw32-make -j${_cpu_count} build_libs..."
        USES_TERMINAL
        VERBATIM
    )

    add_custom_target(openssl_make_build ALL
        DEPENDS
            "${_openssl_crypto_lib}"
            "${_openssl_ssl_lib}"
        COMMENT "[OpenSSL] Ensuring OpenSSL libraries are built."
    )

    # Create the IMPORTED static library targets
    add_library(openssl_crypto STATIC IMPORTED GLOBAL)
    set_target_properties(openssl_crypto PROPERTIES
        IMPORTED_LOCATION             "${_openssl_crypto_lib}"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
        INTERFACE_LINK_LIBRARIES      "ws2_32;crypt32"
    )
    add_dependencies(openssl_crypto openssl_make_build)

    add_library(openssl_ssl STATIC IMPORTED GLOBAL)
    set_target_properties(openssl_ssl PROPERTIES
        IMPORTED_LOCATION             "${_openssl_ssl_lib}"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
        INTERFACE_LINK_LIBRARIES      "openssl_crypto"
    )
    add_dependencies(openssl_ssl openssl_make_build)

    # Standard namespaced aliases
    add_library(OpenSSL::Crypto INTERFACE IMPORTED GLOBAL)
    set_target_properties(OpenSSL::Crypto PROPERTIES
        INTERFACE_LINK_LIBRARIES      "openssl_crypto"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
    )

    add_library(OpenSSL::SSL INTERFACE IMPORTED GLOBAL)
    set_target_properties(OpenSSL::SSL PROPERTIES
        INTERFACE_LINK_LIBRARIES      "openssl_ssl;openssl_crypto"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
    )

    message(STATUS "[OpenSSL] MinGW build targets ready: OpenSSL::Crypto, OpenSSL::SSL (mingw32-make -j${_cpu_count})")
    message(STATUS "[OpenSSL]   Link with: target_link_libraries(<your_target> OpenSSL::SSL)")

# ===========================================================================
# BUILD: Linux
# ===========================================================================
elseif ("${TARGET_OS}" STREQUAL "Linux")

    # -----------------------------------------------------------------------
    # Step 1. Acquire Perl (use the system Perl)
    # -----------------------------------------------------------------------
    include(cmake/acquire_perl.cmake)
    # → sets PERL_EXECUTABLE, PERL_BIN_DIR

    # -----------------------------------------------------------------------
    # Step 2. Determine the OpenSSL configure target per architecture
    # -----------------------------------------------------------------------
    if ("${TARGET_ARCH}" STREQUAL "x64")
        set(_openssl_configure_target "linux-x86_64")
    elseif ("${TARGET_ARCH}" STREQUAL "x86")
        set(_openssl_configure_target "linux-x86")
    elseif ("${TARGET_ARCH}" STREQUAL "arm64")
        set(_openssl_configure_target "linux-aarch64")
    elseif ("${TARGET_ARCH}" STREQUAL "arm")
        set(_openssl_configure_target "linux-armv4")
    else()
        message(FATAL_ERROR
            "[OpenSSL] Unsupported architecture for the Linux build: ${TARGET_ARCH}\n"
            "Supported: x86, x64, arm64, arm"
        )
    endif()
    message(STATUS "[OpenSSL] Configure target : ${_openssl_configure_target}")

    # -----------------------------------------------------------------------
    # Determine the build type
    # -----------------------------------------------------------------------
    string(TOLOWER "${CMAKE_BUILD_TYPE}" _build_type_lower)
    if (_build_type_lower STREQUAL "debug")
        set(_openssl_debug_flags "--debug")
        message(STATUS "[OpenSSL] Build type : Debug (debug symbols ON)")
    else()
        set(_openssl_debug_flags "")
        message(STATUS "[OpenSSL] Build type : ${CMAKE_BUILD_TYPE} (debug symbols OFF)")
    endif()

    # -----------------------------------------------------------------------
    # Step 3. Run perl Configure (at CMake configure-time)
    # -----------------------------------------------------------------------
    file(MAKE_DIRECTORY "${openssl_BINARY_DIR}")

    message(STATUS "[OpenSSL] Running: perl Configure ${_openssl_configure_target} ${_openssl_debug_flags}")
    message(STATUS "[OpenSSL]   source : ${openssl_SOURCE_DIR}")
    message(STATUS "[OpenSSL]   build  : ${openssl_BINARY_DIR}")

    execute_process(
        COMMAND
            "${PERL_EXECUTABLE}" "${openssl_SOURCE_DIR}/Configure"
            "${_openssl_configure_target}"
            ${_openssl_debug_flags}
            no-shared       # build static libraries only
            no-makedepend   # speeds up the build
        WORKING_DIRECTORY "${openssl_BINARY_DIR}"
        RESULT_VARIABLE   _configure_result
        OUTPUT_VARIABLE   _configure_output
        ERROR_VARIABLE    _configure_error
    )
    # Dropped ECHO_*_VARIABLE (3.18+) → 3.15 compatible. Print the captured output afterwards.
    message(STATUS "${_configure_output}")

    if (NOT _configure_result EQUAL 0)
        message(FATAL_ERROR
            "[OpenSSL] perl Configure failed (exit=${_configure_result}):\n"
            "${_configure_error}"
        )
    endif()

    message(STATUS "[OpenSSL] Configure done.")

    # -----------------------------------------------------------------------
    # Step 4. make build → produces libcrypto.a, libssl.a
    # -----------------------------------------------------------------------
    set(_openssl_crypto_lib "${openssl_BINARY_DIR}/libcrypto.a")
    set(_openssl_ssl_lib    "${openssl_BINARY_DIR}/libssl.a")
    set(_openssl_include
        "${openssl_BINARY_DIR}/include"
        "${openssl_SOURCE_DIR}/include"
    )

    find_program(_linux_make_exe
        NAMES make gmake
        DOC "make for Linux OpenSSL build"
    )
    if (NOT _linux_make_exe)
        message(FATAL_ERROR
            "[OpenSSL] Could not find make.\n"
            "Install it with your package manager:\n"
            "  Ubuntu/Debian : sudo apt install make\n"
            "  Fedora/RHEL   : sudo dnf install make\n"
            "  Arch          : sudo pacman -S make"
        )
    endif()
    message(STATUS "[OpenSSL] make : ${_linux_make_exe}")

    include(ProcessorCount)
    ProcessorCount(_cpu_count)
    if (_cpu_count EQUAL 0)
        set(_cpu_count 4)
    endif()
    message(STATUS "[OpenSSL] make parallel jobs : ${_cpu_count}")

    add_custom_command(
        OUTPUT
            "${_openssl_crypto_lib}"
            "${_openssl_ssl_lib}"
        COMMAND ${CMAKE_COMMAND} -E env
            "PATH=${PERL_BIN_DIR}:$ENV{PATH}"
            "${_linux_make_exe}" -j${_cpu_count} build_libs
        WORKING_DIRECTORY "${openssl_BINARY_DIR}"
        COMMENT "[OpenSSL] Building OpenSSL with make -j${_cpu_count} build_libs..."
        USES_TERMINAL
        VERBATIM
    )

    add_custom_target(openssl_make_build ALL
        DEPENDS
            "${_openssl_crypto_lib}"
            "${_openssl_ssl_lib}"
        COMMENT "[OpenSSL] Ensuring OpenSSL libraries are built."
    )

    # -----------------------------------------------------------------------
    # Create the IMPORTED static library targets
    # -----------------------------------------------------------------------
    add_library(openssl_crypto STATIC IMPORTED GLOBAL)
    set_target_properties(openssl_crypto PROPERTIES
        IMPORTED_LOCATION             "${_openssl_crypto_lib}"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
        INTERFACE_LINK_LIBRARIES      "pthread;dl"
    )
    add_dependencies(openssl_crypto openssl_make_build)

    add_library(openssl_ssl STATIC IMPORTED GLOBAL)
    set_target_properties(openssl_ssl PROPERTIES
        IMPORTED_LOCATION             "${_openssl_ssl_lib}"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
        INTERFACE_LINK_LIBRARIES      "openssl_crypto"
    )
    add_dependencies(openssl_ssl openssl_make_build)

    # Standard namespaced aliases
    add_library(OpenSSL::Crypto INTERFACE IMPORTED GLOBAL)
    set_target_properties(OpenSSL::Crypto PROPERTIES
        INTERFACE_LINK_LIBRARIES      "openssl_crypto"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
    )

    add_library(OpenSSL::SSL INTERFACE IMPORTED GLOBAL)
    set_target_properties(OpenSSL::SSL PROPERTIES
        INTERFACE_LINK_LIBRARIES      "openssl_ssl;openssl_crypto"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
    )

    message(STATUS "[OpenSSL] Linux build targets ready: OpenSSL::Crypto, OpenSSL::SSL (make -j${_cpu_count})")
    message(STATUS "[OpenSSL]   Link with: target_link_libraries(<your_target> OpenSSL::SSL)")

# ===========================================================================
# BUILD: Android  (NDK clang cross-compile)
# ===========================================================================
elseif ("${TARGET_OS}" STREQUAL "Android")

    # -----------------------------------------------------------------------
    # Step 1. Acquire Perl (runs on the host - for the cross-compiling build machine)
    # -----------------------------------------------------------------------
    include(cmake/acquire_perl.cmake)
    # → sets PERL_EXECUTABLE, PERL_BIN_DIR

    # -----------------------------------------------------------------------
    # Step 2. Determine ANDROID_NDK_ROOT
    #   Priority: CMake variable > ANDROID_NDK_ROOT env var > ANDROID_NDK_HOME
    #   Android Studio sets CMAKE_ANDROID_NDK automatically.
    # -----------------------------------------------------------------------
    if (NOT ANDROID_NDK_ROOT)
        if (DEFINED CMAKE_ANDROID_NDK AND CMAKE_ANDROID_NDK)
            set(ANDROID_NDK_ROOT "${CMAKE_ANDROID_NDK}")
        elseif (DEFINED ENV{ANDROID_NDK_ROOT} AND EXISTS "$ENV{ANDROID_NDK_ROOT}")
            set(ANDROID_NDK_ROOT "$ENV{ANDROID_NDK_ROOT}")
        elseif (DEFINED ENV{ANDROID_NDK_HOME} AND EXISTS "$ENV{ANDROID_NDK_HOME}")
            set(ANDROID_NDK_ROOT "$ENV{ANDROID_NDK_HOME}")
        else()
            message(FATAL_ERROR
                "[OpenSSL] Could not find ANDROID_NDK_ROOT.\n"
                "Set one of the following:\n"
                "  - CMAKE_ANDROID_NDK (CMake variable, set automatically by Android Studio)\n"
                "  - ANDROID_NDK_ROOT  (environment variable)\n"
                "  - ANDROID_NDK_HOME  (environment variable)"
            )
        endif()
    endif()
    message(STATUS "[OpenSSL] ANDROID_NDK_ROOT : ${ANDROID_NDK_ROOT}")

    # -----------------------------------------------------------------------
    # Step 3. Determine the NDK LLVM toolchain bin directory
    #   Path: <ndk>/toolchains/llvm/prebuilt/<host-tag>/bin
    #   host-tag: linux-x86_64 / darwin-x86_64|arm64 / windows-x86_64
    # -----------------------------------------------------------------------
    if (CMAKE_HOST_WIN32)
        set(_ndk_host_tag "windows-x86_64")
    elseif (CMAKE_HOST_APPLE)
        if (EXISTS "${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/darwin-arm64")
            set(_ndk_host_tag "darwin-arm64")   # Apple Silicon Mac
        else()
            set(_ndk_host_tag "darwin-x86_64")  # Intel Mac
        endif()
    else()
        set(_ndk_host_tag "linux-x86_64")
    endif()

    set(_ndk_llvm_bin "${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${_ndk_host_tag}/bin")
    if (NOT EXISTS "${_ndk_llvm_bin}")
        message(FATAL_ERROR
            "[OpenSSL] Could not find the NDK LLVM bin directory:\n"
            "  ${_ndk_llvm_bin}\n"
            "Check the NDK path and version."
        )
    endif()
    message(STATUS "[OpenSSL] NDK LLVM bin : ${_ndk_llvm_bin}")

    # -----------------------------------------------------------------------
    # Step 4. Determine the OpenSSL configure target per architecture
    #   ANDROID_ABI (Gradle abiFilters) → OpenSSL Configure target name
    # -----------------------------------------------------------------------
    if ("${ANDROID_ABI}" STREQUAL "arm64-v8a")
        set(_openssl_configure_target "android-arm64")
    elseif ("${ANDROID_ABI}" STREQUAL "armeabi-v7a")
        set(_openssl_configure_target "android-arm")
    elseif ("${ANDROID_ABI}" STREQUAL "x86_64")
        set(_openssl_configure_target "android-x86_64")
    elseif ("${ANDROID_ABI}" STREQUAL "x86")
        set(_openssl_configure_target "android-x86")
    else()
        message(FATAL_ERROR
            "[OpenSSL] Unsupported Android ABI: ${ANDROID_ABI}\n"
            "Supported: arm64-v8a, armeabi-v7a, x86_64, x86"
        )
    endif()
    message(STATUS "[OpenSSL] Configure target : ${_openssl_configure_target}")

    # -----------------------------------------------------------------------
    # Step 5. Determine the Android API level
    #   ANDROID_PLATFORM has the form "android-35" → extract just the number
    #   Or ANDROID_NATIVE_API_LEVEL (already a number)
    # -----------------------------------------------------------------------
    if (ANDROID_PLATFORM)
        string(REGEX REPLACE "^android-" "" _api_level "${ANDROID_PLATFORM}")
    elseif (ANDROID_NATIVE_API_LEVEL)
        set(_api_level "${ANDROID_NATIVE_API_LEVEL}")
    else()
        set(_api_level "21")
        message(WARNING "[OpenSSL] Could not detect the Android API level; falling back to the default of 21.")
    endif()
    message(STATUS "[OpenSSL] Android API level : ${_api_level}")

    # -----------------------------------------------------------------------
    # Determine the build type
    # -----------------------------------------------------------------------
    string(TOLOWER "${CMAKE_BUILD_TYPE}" _build_type_lower)
    if (_build_type_lower STREQUAL "debug")
        set(_openssl_debug_flags "--debug")
        message(STATUS "[OpenSSL] Build type : Debug (debug symbols ON)")
    else()
        set(_openssl_debug_flags "")
        message(STATUS "[OpenSSL] Build type : ${CMAKE_BUILD_TYPE} (debug symbols OFF)")
    endif()

    # -----------------------------------------------------------------------
    # Step 6. Run perl Configure (at CMake configure-time)
    #
    # Environment variables OpenSSL Configure needs in order to find the NDK:
    #   ANDROID_NDK_ROOT - the NDK root path
    #   PATH             - the bin dir containing NDK clang, llvm-ar, etc.
    #
    # Windows host - going through MSYS2 bash is mandatory:
    #   OpenSSL's 15-android.conf checks full paths with Perl's -f operator:
    #     -f "$ndk/toolchains/.../bin/aarch64-linux-android-clang"
    #   On Windows, NDK R25+ only ships .cmd files, so -f fails under native Perl.
    #   When run inside MSYS2 bash, the POSIX layer exposes the .cmd files without
    #   their extension.
    #   → Convert the paths to Unix form with cygpath, then run via bash.
    # -----------------------------------------------------------------------
    file(MAKE_DIRECTORY "${openssl_BINARY_DIR}")

    message(STATUS "[OpenSSL] Running: perl Configure ${_openssl_configure_target} -D__ANDROID_API__=${_api_level} ${_openssl_debug_flags}")
    message(STATUS "[OpenSSL]   source : ${openssl_SOURCE_DIR}")
    message(STATUS "[OpenSSL]   build  : ${openssl_BINARY_DIR}")

    if (CMAKE_HOST_WIN32)
        # acquire_perl/mingw.cmake sets _msys2_bash (_msys2_root/usr/bin/bash.exe)
        if (NOT _msys2_bash OR NOT EXISTS "${_msys2_bash}")
            message(FATAL_ERROR
                "[OpenSSL] Could not find MSYS2 bash: ${_msys2_bash}\n"
                "Check that the Perl acquisition step (MSYS2) completed successfully."
            )
        endif()

        # ANDROID_NDK_ROOT / PATH go through cygpath because MSYS2 bash has to locate NDK clang
        # The cd / perl paths stay in Windows form:
        #   → perl records the source path in the Makefile in Windows form (D:/...)
        #   → the NDK make.exe can then correctly find the configdata.pm dependency file
        # bash -l : login shell → includes the standard MSYS2 tool PATH
        string(CONCAT _bash_configure_cmd
            "set -e"
            " && export ANDROID_NDK_ROOT=$(cygpath -u '${ANDROID_NDK_ROOT}')"
            " && export PATH=$(cygpath -u '${_ndk_llvm_bin}'):$PATH"
            " && cd '${openssl_BINARY_DIR}'"
            " && perl '${openssl_SOURCE_DIR}/Configure'"
            " '${_openssl_configure_target}'"
            " '-D__ANDROID_API__=${_api_level}'"
            " ${_openssl_debug_flags}"
            " no-shared no-makedepend"
        )
        execute_process(
            COMMAND "${_msys2_bash}" -l -c "${_bash_configure_cmd}"
            RESULT_VARIABLE   _configure_result
            OUTPUT_VARIABLE   _configure_output
            ERROR_VARIABLE    _configure_error
        )
        # Dropped ECHO_*_VARIABLE (3.18+) → 3.15 compatible. Print the captured output afterwards.
        message(STATUS "${_configure_output}")
    else()
        # Linux / macOS host: run perl directly
        set(ENV{ANDROID_NDK_ROOT} "${ANDROID_NDK_ROOT}")
        set(ENV{PATH} "${_ndk_llvm_bin}:${PERL_BIN_DIR}:$ENV{PATH}")
        execute_process(
            COMMAND
                "${PERL_EXECUTABLE}" "${openssl_SOURCE_DIR}/Configure"
                "${_openssl_configure_target}"
                -D__ANDROID_API__=${_api_level}
                ${_openssl_debug_flags}
                no-shared       # build static libraries only
                no-makedepend   # speeds up the build
            WORKING_DIRECTORY "${openssl_BINARY_DIR}"
            RESULT_VARIABLE   _configure_result
            OUTPUT_VARIABLE   _configure_output
            ERROR_VARIABLE    _configure_error
        )
        # Dropped ECHO_*_VARIABLE (3.18+) → 3.15 compatible. Print the captured output afterwards.
        message(STATUS "${_configure_output}")
    endif()

    if (NOT _configure_result EQUAL 0)
        message(FATAL_ERROR
            "[OpenSSL] perl Configure failed (exit=${_configure_result}):\n"
            "${_configure_error}"
        )
    endif()

    message(STATUS "[OpenSSL] Configure done.")

    # -----------------------------------------------------------------------
    # Step 7. make build → produces libcrypto.a, libssl.a
    # -----------------------------------------------------------------------
    set(_openssl_crypto_lib "${openssl_BINARY_DIR}/libcrypto.a")
    set(_openssl_ssl_lib    "${openssl_BINARY_DIR}/libssl.a")
    set(_openssl_include
        "${openssl_BINARY_DIR}/include"
        "${openssl_SOURCE_DIR}/include"
    )

    include(ProcessorCount)
    ProcessorCount(_cpu_count)
    if (_cpu_count EQUAL 0)
        set(_cpu_count 4)
    endif()
    message(STATUS "[OpenSSL] make parallel jobs : ${_cpu_count}")

    # Determine the make bundled with the NDK: only the executable name differs per host OS
    #   _ndk_host_tag was already determined in Step 3
    #   Windows : <ndk>/prebuilt/windows-x86_64/bin/make.exe
    #   Linux   : <ndk>/prebuilt/linux-x86_64/bin/make
    #   macOS   : <ndk>/prebuilt/darwin-x86_64|arm64/bin/make
    if (CMAKE_HOST_WIN32)
        set(_ndk_make_exe "${ANDROID_NDK_ROOT}/prebuilt/${_ndk_host_tag}/bin/make.exe")
    else()
        set(_ndk_make_exe "${ANDROID_NDK_ROOT}/prebuilt/${_ndk_host_tag}/bin/make")
    endif()
    if (NOT EXISTS "${_ndk_make_exe}")
        message(FATAL_ERROR
            "[OpenSSL] Could not find the make bundled with the NDK:\n"
            "  ${_ndk_make_exe}\n"
            "Check the NDK path and version."
        )
    endif()
    message(STATUS "[OpenSSL] NDK make : ${_ndk_make_exe}")

    if (CMAKE_HOST_WIN32)
        # Windows host: go through MSYS2 bash and invoke the NDK make.exe directly via a cygpath-converted path
        string(CONCAT _bash_make_cmd
            "set -e"
            " && export ANDROID_NDK_ROOT=$(cygpath -u '${ANDROID_NDK_ROOT}')"
            " && export PATH=$(cygpath -u '${_ndk_llvm_bin}'):$PATH"
            " && cd $(cygpath -u '${openssl_BINARY_DIR}')"
            " && $(cygpath -u '${_ndk_make_exe}') -j${_cpu_count} build_libs"
        )
        add_custom_command(
            OUTPUT
                "${_openssl_crypto_lib}"
                "${_openssl_ssl_lib}"
            COMMAND "${_msys2_bash}" -l -c "${_bash_make_cmd}"
            WORKING_DIRECTORY "${openssl_BINARY_DIR}"
            COMMENT "[OpenSSL] Building OpenSSL with NDK make -j${_cpu_count} build_libs (MSYS2)..."
            USES_TERMINAL
            VERBATIM
        )
    else()
        # Linux / macOS host: run the NDK's bundled make directly
        add_custom_command(
            OUTPUT
                "${_openssl_crypto_lib}"
                "${_openssl_ssl_lib}"
            COMMAND ${CMAKE_COMMAND} -E env
                "ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT}"
                "PATH=${_ndk_llvm_bin}:${PERL_BIN_DIR}:$ENV{PATH}"
                "${_ndk_make_exe}" -j${_cpu_count} build_libs
            WORKING_DIRECTORY "${openssl_BINARY_DIR}"
            COMMENT "[OpenSSL] Building OpenSSL with NDK make -j${_cpu_count} build_libs..."
            USES_TERMINAL
            VERBATIM
        )
    endif()

    add_custom_target(openssl_make_build ALL
        DEPENDS
            "${_openssl_crypto_lib}"
            "${_openssl_ssl_lib}"
        COMMENT "[OpenSSL] Ensuring OpenSSL libraries are built."
    )

    # -----------------------------------------------------------------------
    # Create the IMPORTED static library targets
    # On Android the Windows-only links such as ws2_32/crypt32 are not needed
    # -----------------------------------------------------------------------
    add_library(openssl_crypto STATIC IMPORTED GLOBAL)
    set_target_properties(openssl_crypto PROPERTIES
        IMPORTED_LOCATION             "${_openssl_crypto_lib}"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
    )
    add_dependencies(openssl_crypto openssl_make_build)

    add_library(openssl_ssl STATIC IMPORTED GLOBAL)
    set_target_properties(openssl_ssl PROPERTIES
        IMPORTED_LOCATION             "${_openssl_ssl_lib}"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
        INTERFACE_LINK_LIBRARIES      "openssl_crypto"
    )
    add_dependencies(openssl_ssl openssl_make_build)

    # -----------------------------------------------------------------------
    # Propagate Android 16KB page alignment
    #
    # A static library (.a) has no notion of ELF segment alignment itself.
    # 16KB alignment is decided when linking the final .so that swallows this .a,
    # so the IMPORTED target must propagate the link options to its consumers.
    # → Any library that links OpenSSL::SSL automatically becomes a 16KB-aligned .so.
    #
    # Android 15+ devices (and the Play Store requirements) mandate 16KB pages.
    # -----------------------------------------------------------------------
    set_property(TARGET openssl_crypto APPEND PROPERTY
        INTERFACE_LINK_OPTIONS
            "-Wl,-z,max-page-size=16384"
            "-Wl,-z,common-page-size=16384"
    )
    message(STATUS "[OpenSSL] Android 16KB page alignment: -Wl,-z,max-page-size=16384")

    # Standard namespaced aliases
    add_library(OpenSSL::Crypto INTERFACE IMPORTED GLOBAL)
    set_target_properties(OpenSSL::Crypto PROPERTIES
        INTERFACE_LINK_LIBRARIES      "openssl_crypto"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
    )

    add_library(OpenSSL::SSL INTERFACE IMPORTED GLOBAL)
    set_target_properties(OpenSSL::SSL PROPERTIES
        INTERFACE_LINK_LIBRARIES      "openssl_ssl;openssl_crypto"
        INTERFACE_INCLUDE_DIRECTORIES "${_openssl_include}"
    )

    message(STATUS "[OpenSSL] Android build targets ready: OpenSSL::Crypto, OpenSSL::SSL (make -j${_cpu_count})")
    message(STATUS "[OpenSSL]   ABI    : ${ANDROID_ABI} → ${_openssl_configure_target}")
    message(STATUS "[OpenSSL]   API    : android-${_api_level}")
    message(STATUS "[OpenSSL]   Link with: target_link_libraries(<your_target> OpenSSL::SSL)")

else()
    message(FATAL_ERROR
        "[OpenSSL] Unsupported build combination: OS=${TARGET_OS}, Compiler=${TARGET_COMPILER}"
    )
endif()

endif() # OPENSSL_CMAKE_USE_PREBUILT
