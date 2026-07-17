# cmake/prebuilt/resolve_triple.cmake
#
# Maps the current build environment to a prebuilt archive triple.
#
# Required variables:
#   TARGET_OS       - CMAKE_SYSTEM_NAME (Windows / Linux / Android)
#   TARGET_ARCH     - result of detectTargetArchitecture() (x64 / x86 / arm64 / arm)
#   TARGET_COMPILER - result of detectTargetCompiler() (msvc / mingw / gcc / clang)
#   ANDROID_ABI     - Android only
#
# Outputs:
#   OUT_TRIPLES       - list of triples to download.
#                       Two entries (debug/release) for MSVC with a multi-config
#                       generator, one entry otherwise.
#   OUT_IS_MSVC_MULTI - TRUE if this is multi-config MSVC
#
# Triple naming:
#   windows-x64-msvc-release   / windows-x64-msvc-debug
#   windows-arm64-msvc-release / windows-arm64-msvc-debug
#   windows-x64-mingw-release
#   linux-x64-release   / linux-arm64-release
#   android-arm64-v8a-release / android-x86_64-release
#
#   Linux, Android and MinGW ship a single release archive.
#   GCC/Clang static libraries link into debug applications without an ABI break,
#   and on Linux the same archive serves both gcc and clang (ABI-compatible
#   static C library), so the compiler is not part of the Linux triple.
#   Only MSVC needs two, because the CRT differs (/MD vs /MDd).

function(resolveOpenSSLPrebuiltTriples OUT_TRIPLES OUT_IS_MSVC_MULTI)

    set(_is_msvc_multi FALSE)
    set(_triples "")

    if ("${TARGET_OS}" STREQUAL "Windows" AND "${TARGET_COMPILER}" STREQUAL "msvc")

        if (NOT ("${TARGET_ARCH}" STREQUAL "x64" OR "${TARGET_ARCH}" STREQUAL "arm64"))
            _opensslPrebuiltUnsupported("windows-${TARGET_ARCH}-msvc")
        endif()

        if (CMAKE_CONFIGURATION_TYPES)
            # Visual Studio / Ninja Multi-Config:
            # the configuration is chosen at build time, so fetch both up front.
            set(_is_msvc_multi TRUE)
            set(_triples "windows-${TARGET_ARCH}-msvc-release" "windows-${TARGET_ARCH}-msvc-debug")
        else()
            string(TOLOWER "${CMAKE_BUILD_TYPE}" _bt)
            if (_bt STREQUAL "debug")
                set(_triples "windows-${TARGET_ARCH}-msvc-debug")
            else()
                set(_triples "windows-${TARGET_ARCH}-msvc-release")
            endif()
        endif()

    elseif ("${TARGET_OS}" STREQUAL "Windows" AND "${TARGET_COMPILER}" STREQUAL "mingw")

        if (NOT "${TARGET_ARCH}" STREQUAL "x64")
            _opensslPrebuiltUnsupported("windows-${TARGET_ARCH}-mingw")
        endif()
        set(_triples "windows-x64-mingw-release")

    elseif ("${TARGET_OS}" STREQUAL "Linux")

        if (NOT ("${TARGET_ARCH}" STREQUAL "x64" OR "${TARGET_ARCH}" STREQUAL "arm64"))
            _opensslPrebuiltUnsupported("linux-${TARGET_ARCH}")
        endif()
        set(_triples "linux-${TARGET_ARCH}-release")

    elseif ("${TARGET_OS}" STREQUAL "Android")

        if ("${ANDROID_ABI}" STREQUAL "arm64-v8a" OR "${ANDROID_ABI}" STREQUAL "x86_64")
            set(_triples "android-${ANDROID_ABI}-release")
        else()
            _opensslPrebuiltUnsupported("android-${ANDROID_ABI}")
        endif()

    else()
        _opensslPrebuiltUnsupported("${TARGET_OS}-${TARGET_ARCH}-${TARGET_COMPILER}")
    endif()

    set(${OUT_TRIPLES}       "${_triples}"       PARENT_SCOPE)
    set(${OUT_IS_MSVC_MULTI} "${_is_msvc_multi}" PARENT_SCOPE)

endfunction()


# Unsupported combination -> fail immediately. Never silently fall back to a
# source build. (An explicit failure beats the user wondering why their build
# suddenly takes 30 minutes.)
macro(_opensslPrebuiltUnsupported _combo)
    message(FATAL_ERROR
        "\n[OpenSSL] No prebuilt binaries are published for this combination: ${_combo}\n"
        "\n"
        "Supported:\n"
        "  windows-x64-msvc    (Debug / Release)\n"
        "  windows-arm64-msvc  (Debug / Release)\n"
        "  windows-x64-mingw   (MSYS2 MINGW64 / msvcrt)\n"
        "  linux-x64           (gcc / clang)\n"
        "  linux-arm64         (gcc / clang)\n"
        "  android-arm64-v8a   (API 21+)\n"
        "  android-x86_64      (API 21+)\n"
        "\n"
        "To use OpenSSL here, build it from source:\n"
        "  cmake -DOPENSSL_CMAKE_USE_PREBUILT=OFF ...\n"
        "or, in your project's CMakeLists.txt before FetchContent:\n"
        "  set(OPENSSL_CMAKE_USE_PREBUILT OFF CACHE BOOL \"\" FORCE)\n"
    )
endmacro()
