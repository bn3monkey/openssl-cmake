# cmake/prebuilt/fetch_prebuilt.cmake
#
# Downloads the prebuilt OpenSSL static libraries published as GitHub Release
# assets and creates the OpenSSL::SSL / OpenSSL::Crypto IMPORTED targets.
#
# This produces the same targets as the source-build path, so consuming
# projects need no changes.
#
# Required variables:
#   OPENSSL_VERSION            - e.g. 3.6.1
#   OPENSSL_CMAKE_PREBUILT_TAG - release tag, e.g. v1.1.0
#   TARGET_OS / TARGET_ARCH / TARGET_COMPILER
#
# Optional variables:
#   OPENSSL_CMAKE_PREBUILT_URL - override the asset base URL
#                                (internal mirror / air-gapped network)
#
# Output location:
#   ${CMAKE_CURRENT_BINARY_DIR}/prebuilt/<triple>/{include,lib}

include(cmake/prebuilt/resolve_triple.cmake)

resolveOpenSSLPrebuiltTriples(_ossl_triples _ossl_msvc_multi)
message(STATUS "[OpenSSL] Prebuilt triples : ${_ossl_triples}")

# ---------------------------------------------------------------------------
# Determine the base URL
# ---------------------------------------------------------------------------
if (NOT OPENSSL_CMAKE_PREBUILT_URL)
    set(OPENSSL_CMAKE_PREBUILT_URL
        "https://github.com/bn3monkey/openssl-cmake/releases/download/${OPENSSL_CMAKE_PREBUILT_TAG}")
endif()
message(STATUS "[OpenSSL] Prebuilt base URL : ${OPENSSL_CMAKE_PREBUILT_URL}")

set(_ossl_prebuilt_root "${CMAKE_CURRENT_BINARY_DIR}/prebuilt")

# ---------------------------------------------------------------------------
# Fetch the manifest
#
# If every required triple is already extracted, skip the network entirely so
# that re-configuring does not hit GitHub on every run.
# ---------------------------------------------------------------------------
set(_ossl_need_download FALSE)
foreach(_t IN LISTS _ossl_triples)
    if (NOT EXISTS "${_ossl_prebuilt_root}/${_t}/.openssl-${OPENSSL_VERSION}.stamp")
        set(_ossl_need_download TRUE)
    endif()
endforeach()

if (_ossl_need_download)

    set(_ossl_manifest "${_ossl_prebuilt_root}/prebuilt-manifest.cmake")
    message(STATUS "[OpenSSL] Fetching manifest ...")

    file(DOWNLOAD
        "${OPENSSL_CMAKE_PREBUILT_URL}/prebuilt-manifest.cmake"
        "${_ossl_manifest}"
        STATUS  _ossl_dl_status
        TIMEOUT 60
    )
    list(GET _ossl_dl_status 0 _ossl_dl_code)
    if (NOT _ossl_dl_code EQUAL 0)
        list(GET _ossl_dl_status 1 _ossl_dl_msg)
        file(REMOVE "${_ossl_manifest}")
        message(FATAL_ERROR
            "\n[OpenSSL] Failed to download the prebuilt manifest (code=${_ossl_dl_code}): ${_ossl_dl_msg}\n"
            "  URL: ${OPENSSL_CMAKE_PREBUILT_URL}/prebuilt-manifest.cmake\n"
            "\n"
            "Things to check:\n"
            "  - network / proxy connectivity\n"
            "  - whether the release tag ${OPENSSL_CMAKE_PREBUILT_TAG} actually exists\n"
            "\n"
            "If you are offline, build from source: -DOPENSSL_CMAKE_USE_PREBUILT=OFF\n"
        )
    endif()

    include("${_ossl_manifest}")
    # -> defines OPENSSL_PREBUILT_VERSION, OPENSSL_PREBUILT_TRIPLES,
    #    OPENSSL_PREBUILT_SHA256_<triple>

    if (NOT "${OPENSSL_PREBUILT_VERSION}" STREQUAL "${OPENSSL_VERSION}")
        message(FATAL_ERROR
            "\n[OpenSSL] Release ${OPENSSL_CMAKE_PREBUILT_TAG} ships OpenSSL "
            "${OPENSSL_PREBUILT_VERSION}, but this CMakeLists requires ${OPENSSL_VERSION}.\n"
            "Point OPENSSL_CMAKE_PREBUILT_TAG at a matching release, "
            "or use -DOPENSSL_CMAKE_USE_PREBUILT=OFF.\n"
        )
    endif()

endif()

# ---------------------------------------------------------------------------
# Download and extract each triple
# ---------------------------------------------------------------------------
foreach(_t IN LISTS _ossl_triples)

    set(_dest  "${_ossl_prebuilt_root}/${_t}")
    set(_stamp "${_dest}/.openssl-${OPENSSL_VERSION}.stamp")

    if (EXISTS "${_stamp}")
        message(STATUS "[OpenSSL] Prebuilt ready (cached) : ${_t}")
        continue()
    endif()

    list(FIND OPENSSL_PREBUILT_TRIPLES "${_t}" _idx)
    if (_idx EQUAL -1)
        message(FATAL_ERROR
            "\n[OpenSSL] Release ${OPENSSL_CMAKE_PREBUILT_TAG} does not contain the triple '${_t}'.\n"
            "This release provides: ${OPENSSL_PREBUILT_TRIPLES}\n"
            "To build from source: -DOPENSSL_CMAKE_USE_PREBUILT=OFF\n"
        )
    endif()

    set(_archive_name "openssl-${OPENSSL_VERSION}-${_t}.tar.gz")
    set(_archive      "${_ossl_prebuilt_root}/${_archive_name}")
    set(_sha256       "${OPENSSL_PREBUILT_SHA256_${_t}}")

    message(STATUS "[OpenSSL] Downloading ${_archive_name} ...")
    file(DOWNLOAD
        "${OPENSSL_CMAKE_PREBUILT_URL}/${_archive_name}"
        "${_archive}"
        EXPECTED_HASH SHA256=${_sha256}
        STATUS        _ossl_dl_status
        TIMEOUT       600
        SHOW_PROGRESS
    )
    list(GET _ossl_dl_status 0 _ossl_dl_code)
    if (NOT _ossl_dl_code EQUAL 0)
        list(GET _ossl_dl_status 1 _ossl_dl_msg)
        file(REMOVE "${_archive}")
        message(FATAL_ERROR
            "\n[OpenSSL] Prebuilt download failed (code=${_ossl_dl_code}): ${_ossl_dl_msg}\n"
            "  URL: ${OPENSSL_CMAKE_PREBUILT_URL}/${_archive_name}\n"
            "A SHA256 mismatch means the download was corrupted. "
            "Delete ${_ossl_prebuilt_root} and try again.\n"
        )
    endif()

    # Extract into a temporary directory and rename into place. This keeps a
    # half-extracted directory from being read by another project building in
    # parallel.
    set(_tmp "${_ossl_prebuilt_root}/.tmp-${_t}")
    file(REMOVE_RECURSE "${_tmp}")
    file(MAKE_DIRECTORY "${_tmp}")

    # file(ARCHIVE_EXTRACT) requires CMake 3.18+; use cmake -E tar to stay 3.15 compatible.
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E tar xzf "${_archive}"
        WORKING_DIRECTORY "${_tmp}"
        RESULT_VARIABLE _ossl_extract_result
    )
    file(REMOVE "${_archive}")

    if (NOT _ossl_extract_result EQUAL 0)
        file(REMOVE_RECURSE "${_tmp}")
        message(FATAL_ERROR "[OpenSSL] Failed to extract archive: ${_archive_name}")
    endif()

    if (NOT EXISTS "${_tmp}/lib")
        file(REMOVE_RECURSE "${_tmp}")
        message(FATAL_ERROR
            "[OpenSSL] Malformed archive (no lib/ directory): ${_archive_name}")
    endif()

    file(REMOVE_RECURSE "${_dest}")
    file(RENAME "${_tmp}" "${_dest}")
    file(WRITE  "${_stamp}" "${OPENSSL_VERSION} ${_t}\n")

    message(STATUS "[OpenSSL] Prebuilt ready : ${_t}")

endforeach()

# ---------------------------------------------------------------------------
# Per-platform library file names and system link dependencies
# ---------------------------------------------------------------------------
if ("${TARGET_OS}" STREQUAL "Windows" AND "${TARGET_COMPILER}" STREQUAL "msvc")
    set(_ossl_crypto_name "libcrypto.lib")
    set(_ossl_ssl_name    "libssl.lib")
    set(_ossl_syslibs     "ws2_32;crypt32")
elseif ("${TARGET_OS}" STREQUAL "Windows")
    set(_ossl_crypto_name "libcrypto.a")
    set(_ossl_ssl_name    "libssl.a")
    set(_ossl_syslibs     "ws2_32;crypt32")
elseif ("${TARGET_OS}" STREQUAL "Linux")
    set(_ossl_crypto_name "libcrypto.a")
    set(_ossl_ssl_name    "libssl.a")
    set(_ossl_syslibs     "pthread;dl")
else() # Android
    set(_ossl_crypto_name "libcrypto.a")
    set(_ossl_ssl_name    "libssl.a")
    set(_ossl_syslibs     "")
endif()

# ---------------------------------------------------------------------------
# Create the IMPORTED targets
#
# MSVC + multi-config: register both Debug and Release via IMPORTED_LOCATION_<CONFIG>.
#   Visual Studio generators leave CMAKE_BUILD_TYPE empty and pick the config at
#   build time, so a single IMPORTED_LOCATION would end up with a mismatched CRT.
#   RelWithDebInfo and MinSizeRel map to Release (/MD).
# Everything else: a single IMPORTED_LOCATION.
# ---------------------------------------------------------------------------
add_library(openssl_crypto STATIC IMPORTED GLOBAL)
add_library(openssl_ssl    STATIC IMPORTED GLOBAL)

if (_ossl_msvc_multi)

    set(_rel_dir "${_ossl_prebuilt_root}/windows-x64-msvc-release")
    set(_dbg_dir "${_ossl_prebuilt_root}/windows-x64-msvc-debug")

    set(_ossl_include "${_rel_dir}/include")

    set_target_properties(openssl_crypto PROPERTIES
        IMPORTED_CONFIGURATIONS        "RELEASE;DEBUG"
        IMPORTED_LOCATION_RELEASE      "${_rel_dir}/lib/${_ossl_crypto_name}"
        IMPORTED_LOCATION_DEBUG        "${_dbg_dir}/lib/${_ossl_crypto_name}"
        MAP_IMPORTED_CONFIG_RELWITHDEBINFO "Release"
        MAP_IMPORTED_CONFIG_MINSIZEREL     "Release"
        INTERFACE_INCLUDE_DIRECTORIES  "${_ossl_include}"
        INTERFACE_LINK_LIBRARIES       "${_ossl_syslibs}"
    )
    set_target_properties(openssl_ssl PROPERTIES
        IMPORTED_CONFIGURATIONS        "RELEASE;DEBUG"
        IMPORTED_LOCATION_RELEASE      "${_rel_dir}/lib/${_ossl_ssl_name}"
        IMPORTED_LOCATION_DEBUG        "${_dbg_dir}/lib/${_ossl_ssl_name}"
        MAP_IMPORTED_CONFIG_RELWITHDEBINFO "Release"
        MAP_IMPORTED_CONFIG_MINSIZEREL     "Release"
        INTERFACE_INCLUDE_DIRECTORIES  "${_ossl_include}"
        INTERFACE_LINK_LIBRARIES       "openssl_crypto"
    )

else()

    list(GET _ossl_triples 0 _ossl_t)
    set(_ossl_dir     "${_ossl_prebuilt_root}/${_ossl_t}")
    set(_ossl_include "${_ossl_dir}/include")

    set_target_properties(openssl_crypto PROPERTIES
        IMPORTED_LOCATION             "${_ossl_dir}/lib/${_ossl_crypto_name}"
        INTERFACE_INCLUDE_DIRECTORIES "${_ossl_include}"
        INTERFACE_LINK_LIBRARIES      "${_ossl_syslibs}"
    )
    set_target_properties(openssl_ssl PROPERTIES
        IMPORTED_LOCATION             "${_ossl_dir}/lib/${_ossl_ssl_name}"
        INTERFACE_INCLUDE_DIRECTORIES "${_ossl_include}"
        INTERFACE_LINK_LIBRARIES      "openssl_crypto"
    )

endif()

# ---------------------------------------------------------------------------
# Android: propagate 16 KB page alignment
#
# A static library (.a) has no notion of ELF segment alignment. 16 KB alignment
# is decided when the final .so that swallows this .a is linked, so the IMPORTED
# target has to propagate the link options to consumers.
# -> any library linking OpenSSL::SSL automatically produces a 16 KB aligned .so.
#
# Android 15+ devices (and the Play Store) require 16 KB page support.
# ---------------------------------------------------------------------------
if ("${TARGET_OS}" STREQUAL "Android")
    set(_ossl_page_opts "-Wl,-z,max-page-size=16384" "-Wl,-z,common-page-size=16384")
    set_property(TARGET openssl_crypto APPEND PROPERTY
        INTERFACE_LINK_OPTIONS ${_ossl_page_opts})
    message(STATUS "[OpenSSL] Android 16KB page alignment: -Wl,-z,max-page-size=16384")
endif()

# ---------------------------------------------------------------------------
# Standard namespaced aliases (identical to the source-build path)
# ---------------------------------------------------------------------------
add_library(OpenSSL::Crypto INTERFACE IMPORTED GLOBAL)
set_target_properties(OpenSSL::Crypto PROPERTIES
    INTERFACE_LINK_LIBRARIES      "openssl_crypto"
    INTERFACE_INCLUDE_DIRECTORIES "${_ossl_include}"
)

add_library(OpenSSL::SSL INTERFACE IMPORTED GLOBAL)
set_target_properties(OpenSSL::SSL PROPERTIES
    INTERFACE_LINK_LIBRARIES      "openssl_ssl;openssl_crypto"
    INTERFACE_INCLUDE_DIRECTORIES "${_ossl_include}"
)

message(STATUS "[OpenSSL] Prebuilt targets ready: OpenSSL::Crypto, OpenSSL::SSL")
message(STATUS "[OpenSSL]   Link with: target_link_libraries(<your_target> OpenSSL::SSL)")
