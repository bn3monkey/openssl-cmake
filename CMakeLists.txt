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

# ===========================================================================
# DOWNLOAD OPENSSL SOURCE
# ===========================================================================
include(FetchContent)
set(OpenSSL_URL "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz")
message(STATUS "OpenSSL URL : ${OpenSSL_URL}")

if (NOT ANDROID)
FetchContent_Declare(
    OpenSSL
    URL "${OpenSSL_URL}"
    URL_HASH SHA256=b1bfedcd5b289ff22aee87c9d600f515767ebf45f77168cb6d64f231f518a82e
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
else()
    FetchContent_Declare(
        OpenSSL
        GIT_REPOSITORY https://github.com/openssl/openssl.git
        GIT_TAG        openssl-${OPENSSL_VERSION}
        GIT_SHALLOW    TRUE
        GIT_PROGRESS   TRUE   # ← 이게 git clone --progress 와 동일
        GIT_SUBMODULES "" 
    )
endif()

FetchContent_MakeAvailable(OpenSSL)

# FetchContent가 설정한 변수 확인
# FetchContent_Declare 이름 "OpenSSL" → 소문자 변수
#   openssl_SOURCE_DIR : 소스 코드 위치 (_deps/openssl-src)
#   openssl_BINARY_DIR : 빌드 출력 위치 (_deps/openssl-build)
if (NOT openssl_SOURCE_DIR)
    message(FATAL_ERROR "[OpenSSL] openssl_SOURCE_DIR is not set. FetchContent failed?")
endif()
message(STATUS "OpenSSL source dir : ${openssl_SOURCE_DIR}")
message(STATUS "OpenSSL build dir  : ${openssl_BINARY_DIR}")


# ===========================================================================
# BUILD: Windows + MSVC
# ===========================================================================
if ("${TARGET_OS}" STREQUAL "Windows" AND "${TARGET_COMPILER}" STREQUAL "msvc")

    # -----------------------------------------------------------------------
    # Step 1. Perl 획득
    # -----------------------------------------------------------------------
    include(cmake/acquire_perl.cmake)
    # → PERL_EXECUTABLE, PERL_BIN_DIR 설정됨

    # -----------------------------------------------------------------------
    # Step 2. NASM 획득
    # -----------------------------------------------------------------------
    include(cmake/acquire_nasm.cmake)
    # → NASM_EXECUTABLE, NASM_BIN_DIR 설정됨

    # -----------------------------------------------------------------------
    # Step 2-1. JOM 획득 (병렬 nmake 대체재)
    # -----------------------------------------------------------------------
    include(cmake/acquire_jom.cmake)
    # → JOM_EXECUTABLE, JOM_BIN_DIR 설정됨

    # -----------------------------------------------------------------------
    # Step 3. 현재 CMake 프로세스의 PATH에 Perl/NASM 경로 추가
    #         (configure-time execute_process에서 사용)
    # -----------------------------------------------------------------------
    set(ENV{PATH} "${PERL_BIN_DIR};${NASM_BIN_DIR};$ENV{PATH}")
    message(STATUS "[OpenSSL] PATH prepended with Perl and NASM bin dirs.")

    # -----------------------------------------------------------------------
    # Step 4. 아키텍처별 OpenSSL configure 타겟 결정
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
        # AMD64 = x86_64와 동일 (OpenSSL은 별도 AMD 타겟을 제공하지 않음)
        set(_openssl_configure_target "VC-WIN64A")

    else()
        message(FATAL_ERROR
            "[OpenSSL] MSVC 빌드에서 지원하지 않는 아키텍처: ${TARGET_ARCH}\n"
            "지원 목록: x86, x64, arm64, amd"
        )
    endif()
    message(STATUS "[OpenSSL] Configure target : ${_openssl_configure_target}")

    # -----------------------------------------------------------------------
    # 빌드 타입 결정 (Debug 모드 시 디버그 심볼 포함)
    #
    # --debug 플래그가 활성화되면 OpenSSL은 다음을 적용함:
    #   - 컴파일러 플래그: /Zi (PDB 생성), /Od (최적화 Off), /RTC1 (런타임 검사)
    #   - 디버그 CRT 링크: /MDd
    #   - 출력: libcrypto.pdb, libssl.pdb (Visual Studio 심볼 추적 가능)
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
    # perl Configure 실행 (CMake configure-time, 매번 실행)
    #
    # Out-of-source 빌드:
    #   소스  : openssl_SOURCE_DIR  (_deps/openssl-src)
    #   결과물: openssl_BINARY_DIR  (_deps/openssl-build)
    # -----------------------------------------------------------------------
    file(MAKE_DIRECTORY "${openssl_BINARY_DIR}")

    message(STATUS "[OpenSSL] Running: perl Configure ${_openssl_configure_target} ${_openssl_debug_flags}")
    message(STATUS "[OpenSSL]   source : ${openssl_SOURCE_DIR}")
    message(STATUS "[OpenSSL]   build  : ${openssl_BINARY_DIR}")

    execute_process(
        COMMAND
            "${PERL_EXECUTABLE}" "${openssl_SOURCE_DIR}/Configure"
            "${_openssl_configure_target}"
            ${_openssl_debug_flags}    # Debug: --debug / Release: (없음)
            no-shared                  # 정적 라이브러리만 빌드
            no-makedepend              # 빌드 속도 향상
        WORKING_DIRECTORY "${openssl_BINARY_DIR}"
        RESULT_VARIABLE   _configure_result
        OUTPUT_VARIABLE   _configure_output
        ERROR_VARIABLE    _configure_error
        ECHO_OUTPUT_VARIABLE
        ECHO_ERROR_VARIABLE
    )

    if (NOT _configure_result EQUAL 0)
        message(FATAL_ERROR
            "[OpenSSL] perl Configure 실패 (exit=${_configure_result}):\n"
            "${_configure_error}"
        )
    endif()

    message(STATUS "[OpenSSL] Configure 완료.")

    # -----------------------------------------------------------------------
    # Step 5. jom 빌드 → OpenSSL::Crypto, OpenSSL::SSL 타겟 생성
    #
    # cmake -E env 로 Perl/NASM PATH를 주입한 뒤 jom을 직접 실행한다.
    # jom은 nmake와 호환되며 병렬 빌드(-j)를 지원하여 빌드 속도가 빠름.
    #
    # ※ PATH에 세미콜론(;)을 포함시키는 방법:
    #   CMake COMMAND 리스트에서 ';'는 인자 구분자로 해석되므로 직접 쓸 수 없음.
    #   $<SEMICOLON> 제너레이터 표현식을 사용하면:
    #     - configure 시점: CMake 리스트 구분자로 파싱되지 않음
    #     - generate  시점: 실제 ';' 문자로 확장됨
    # -----------------------------------------------------------------------
    # out-of-source 빌드이므로 라이브러리와 생성 헤더가 openssl_BINARY_DIR에 위치
    set(_openssl_crypto_lib "${openssl_BINARY_DIR}/libcrypto.lib")
    set(_openssl_ssl_lib    "${openssl_BINARY_DIR}/libssl.lib")
    # include: 빌드 디렉토리(opensslconf.h 등 생성 헤더) + 소스 디렉토리(원본 헤더)
    set(_openssl_include
        "${openssl_BINARY_DIR}/include"
        "${openssl_SOURCE_DIR}/include"
    )

    # 병렬 job 수: 프로세서 수만큼 병렬 빌드
    include(ProcessorCount)
    ProcessorCount(_cpu_count)
    if (_cpu_count EQUAL 0)
        set(_cpu_count 4)   # 감지 실패 시 기본값
    endif()
    message(STATUS "[OpenSSL] jom parallel jobs : ${_cpu_count}")

    # jom을 직접 실행하는 custom command
    # cmake -E env "PATH=<perl>;<nasm>;<기존PATH>" jom -j<N>
    # $<SEMICOLON>이 generate-time에 ';'로 확장되어 PATH 구분자로 동작함
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
        USES_TERMINAL   # Ninja console pool → 터미널 직접 연결 → 실시간 출력
        VERBATIM
    )

    # 빌드 타겟: ALL에 포함시켜 항상 빌드되도록 함
    add_custom_target(openssl_jom_build ALL
        DEPENDS
            "${_openssl_crypto_lib}"
            "${_openssl_ssl_lib}"
        COMMENT "[OpenSSL] Ensuring OpenSSL libraries are built."
    )

    # Debug 빌드 시 PDB(심볼) 파일 경로 설정
    # OpenSSL --debug 빌드가 생성하는 PDB: Visual Studio에서 Step-Into 디버깅 가능
    if (_build_type_lower STREQUAL "debug")
        set(_openssl_crypto_pdb "${openssl_BINARY_DIR}/libcrypto.pdb")
        set(_openssl_ssl_pdb    "${openssl_BINARY_DIR}/libssl.pdb")
    else()
        set(_openssl_crypto_pdb "")
        set(_openssl_ssl_pdb    "")
    endif()

    # IMPORTED 정적 라이브러리 타겟 생성
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

    # 표준 네임스페이스 별칭 (INTERFACE IMPORTED로 래핑)
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
# BUILD: Windows + MinGW (Qt 번들 MinGW)
# ===========================================================================
elseif ("${TARGET_OS}" STREQUAL "Windows" AND "${TARGET_COMPILER}" STREQUAL "mingw")

    # -----------------------------------------------------------------------
    # Step 1. Perl 획득 (Strawberry Perl - MSVC와 동일하게 재사용)
    # -----------------------------------------------------------------------
    include(cmake/acquire_perl.cmake)
    # → PERL_EXECUTABLE, PERL_BIN_DIR 설정됨

    # -----------------------------------------------------------------------
    # Step 2. NASM 획득
    # -----------------------------------------------------------------------
    include(cmake/acquire_nasm.cmake)
    # → NASM_EXECUTABLE, NASM_BIN_DIR 설정됨

    # -----------------------------------------------------------------------
    # Step 3. Qt MinGW bin 디렉토리 확인
    #         CMAKE_C_COMPILER → .../mingwXXXX_64/bin/gcc.exe
    # -----------------------------------------------------------------------
    get_filename_component(_mingw_bin_dir "${CMAKE_C_COMPILER}" DIRECTORY)
    message(STATUS "[OpenSSL] MinGW bin dir : ${_mingw_bin_dir}")

    # -----------------------------------------------------------------------
    # Step 4. 현재 CMake 프로세스의 PATH에 Perl/NASM/MinGW 경로 추가
    #         (configure-time execute_process에서 사용)
    # -----------------------------------------------------------------------
    set(ENV{PATH} "${PERL_BIN_DIR};${NASM_BIN_DIR};${_mingw_bin_dir};$ENV{PATH}")
    message(STATUS "[OpenSSL] PATH prepended with Perl, NASM, and MinGW bin dirs.")

    # -----------------------------------------------------------------------
    # Step 5. 아키텍처별 OpenSSL configure 타겟 결정
    # -----------------------------------------------------------------------
    if ("${TARGET_ARCH}" STREQUAL "x64")
        set(_openssl_configure_target "mingw64")
    elseif ("${TARGET_ARCH}" STREQUAL "x86")
        set(_openssl_configure_target "mingw")
    else()
        message(FATAL_ERROR
            "[OpenSSL] MinGW 빌드에서 지원하지 않는 아키텍처: ${TARGET_ARCH}\n"
            "지원 목록: x86, x64"
        )
    endif()
    message(STATUS "[OpenSSL] Configure target : ${_openssl_configure_target}")

    # -----------------------------------------------------------------------
    # 빌드 타입 결정
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
    # perl Configure 실행 (CMake configure-time, 매번 실행)
    # -----------------------------------------------------------------------
    file(MAKE_DIRECTORY "${openssl_BINARY_DIR}")

    message(STATUS "[OpenSSL] Running: perl Configure ${_openssl_configure_target} ${_openssl_debug_flags}")
    message(STATUS "[OpenSSL]   source : ${openssl_SOURCE_DIR}")
    message(STATUS "[OpenSSL]   build  : ${openssl_BINARY_DIR}")

    execute_process(
        COMMAND
            "${PERL_EXECUTABLE}" "${openssl_SOURCE_DIR}/Configure"
            "${_openssl_configure_target}"
            ${_openssl_debug_flags}    # Debug: --debug / Release: (없음)
            no-shared                  # 정적 라이브러리만 빌드
            no-makedepend              # 빌드 속도 향상
            # SIO_UDP_NETRESET: Qt MinGW 8.1 번들의 구버전 winsock2 헤더에 미정의
            # (Windows 10 SDK 10.0.19041+ 에서 추가된 상수)
            # IOC_IN(0x80000000) | IOC_VENDOR(0x18000000) | 26(0x1A) = 0x9800001A
            -DSIO_UDP_NETRESET=0x9800001A
        WORKING_DIRECTORY "${openssl_BINARY_DIR}"
        RESULT_VARIABLE   _configure_result
        OUTPUT_VARIABLE   _configure_output
        ERROR_VARIABLE    _configure_error
        ECHO_OUTPUT_VARIABLE
        ECHO_ERROR_VARIABLE
    )

    if (NOT _configure_result EQUAL 0)
        message(FATAL_ERROR
            "[OpenSSL] perl Configure 실패 (exit=${_configure_result}):\n"
            "${_configure_error}"
        )
    endif()

    message(STATUS "[OpenSSL] Configure 완료.")

    # -----------------------------------------------------------------------
    # Step 6. mingw32-make 빌드 → OpenSSL::Crypto, OpenSSL::SSL 타겟 생성
    #
    # MinGW 정적 라이브러리 출력: libcrypto.a, libssl.a
    # -----------------------------------------------------------------------
    set(_openssl_crypto_lib "${openssl_BINARY_DIR}/libcrypto.a")
    set(_openssl_ssl_lib    "${openssl_BINARY_DIR}/libssl.a")
    set(_openssl_include
        "${openssl_BINARY_DIR}/include"
        "${openssl_SOURCE_DIR}/include"
    )

    # mingw32-make는 CMAKE_C_COMPILER와 같은 bin 디렉토리에 위치
    find_program(_mingw32_make_exe mingw32-make
        HINTS "${_mingw_bin_dir}"
        NO_DEFAULT_PATH
    )
    if (NOT _mingw32_make_exe)
        message(FATAL_ERROR
            "[OpenSSL] mingw32-make를 찾을 수 없습니다.\n"
            "Qt MinGW 툴체인이 올바르게 설정되었는지 확인하세요.\n"
            "탐색 경로: ${_mingw_bin_dir}"
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

    # IMPORTED 정적 라이브러리 타겟 생성
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

    # 표준 네임스페이스 별칭
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
# BUILD: Linux  (추후 작성 예정)
# ===========================================================================
elseif ("${TARGET_OS}" STREQUAL "Linux")
    message(STATUS "[OpenSSL] Linux build - 추후 구현 예정")

# ===========================================================================
# BUILD: Android  (NDK clang 크로스컴파일)
# ===========================================================================
elseif ("${TARGET_OS}" STREQUAL "Android")

    # -----------------------------------------------------------------------
    # Step 1. Perl 획득 (호스트에서 실행 - 크로스컴파일 빌드 머신용)
    # -----------------------------------------------------------------------
    include(cmake/acquire_perl.cmake)
    # → PERL_EXECUTABLE, PERL_BIN_DIR 설정됨

    # -----------------------------------------------------------------------
    # Step 2. ANDROID_NDK_ROOT 결정
    #   우선순위: CMake 변수 > 환경변수 ANDROID_NDK_ROOT > ANDROID_NDK_HOME
    #   Android Studio는 CMAKE_ANDROID_NDK를 자동으로 설정해준다.
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
                "[OpenSSL] ANDROID_NDK_ROOT를 찾을 수 없습니다.\n"
                "다음 중 하나를 설정하세요:\n"
                "  - CMAKE_ANDROID_NDK (CMake 변수, Android Studio 자동 설정)\n"
                "  - ANDROID_NDK_ROOT  (환경변수)\n"
                "  - ANDROID_NDK_HOME  (환경변수)"
            )
        endif()
    endif()
    message(STATUS "[OpenSSL] ANDROID_NDK_ROOT : ${ANDROID_NDK_ROOT}")

    # -----------------------------------------------------------------------
    # Step 3. NDK LLVM 툴체인 bin 디렉토리 결정
    #   경로: <ndk>/toolchains/llvm/prebuilt/<host-tag>/bin
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
            "[OpenSSL] NDK LLVM bin 디렉토리를 찾을 수 없습니다:\n"
            "  ${_ndk_llvm_bin}\n"
            "NDK 경로와 버전을 확인하세요."
        )
    endif()
    message(STATUS "[OpenSSL] NDK LLVM bin : ${_ndk_llvm_bin}")

    # -----------------------------------------------------------------------
    # Step 4. 아키텍처별 OpenSSL configure 타겟 결정
    #   ANDROID_ABI (Gradle abiFilters) → OpenSSL Configure 타겟명
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
            "[OpenSSL] 지원하지 않는 Android ABI: ${ANDROID_ABI}\n"
            "지원 목록: arm64-v8a, armeabi-v7a, x86_64, x86"
        )
    endif()
    message(STATUS "[OpenSSL] Configure target : ${_openssl_configure_target}")

    # -----------------------------------------------------------------------
    # Step 5. Android API 레벨 결정
    #   ANDROID_PLATFORM = "android-35" 형식 → 숫자만 추출
    #   또는 ANDROID_NATIVE_API_LEVEL (숫자 그대로)
    # -----------------------------------------------------------------------
    if (ANDROID_PLATFORM)
        string(REGEX REPLACE "^android-" "" _api_level "${ANDROID_PLATFORM}")
    elseif (ANDROID_NATIVE_API_LEVEL)
        set(_api_level "${ANDROID_NATIVE_API_LEVEL}")
    else()
        set(_api_level "21")
        message(WARNING "[OpenSSL] Android API 레벨을 감지할 수 없어 기본값 21을 사용합니다.")
    endif()
    message(STATUS "[OpenSSL] Android API level : ${_api_level}")

    # -----------------------------------------------------------------------
    # 빌드 타입 결정
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
    # Step 6. perl Configure 실행 (CMake configure-time)
    #
    # OpenSSL Configure가 NDK를 찾기 위해 필요한 환경변수:
    #   ANDROID_NDK_ROOT - NDK 루트 경로
    #   PATH             - NDK clang(.cmd), llvm-ar 등이 포함된 bin
    #
    # Windows 호스트:
    #   Strawberry Perl(네이티브 Windows)을 사용하므로 cmd.exe 기반으로 동작.
    #   PATH에 NDK bin을 추가하면 .cmd 래퍼를 정상 탐색한다.
    # -----------------------------------------------------------------------
    file(MAKE_DIRECTORY "${openssl_BINARY_DIR}")

    # PATH 구분자: Windows=';', Linux/Mac=':'
    if (CMAKE_HOST_WIN32)
        set(_path_sep ";")
    else()
        set(_path_sep ":")
    endif()

    set(ENV{ANDROID_NDK_ROOT} "${ANDROID_NDK_ROOT}")
    set(ENV{PATH} "${_ndk_llvm_bin}${_path_sep}${PERL_BIN_DIR}${_path_sep}$ENV{PATH}")

    message(STATUS "[OpenSSL] Running: perl Configure ${_openssl_configure_target} -D__ANDROID_API__=${_api_level} ${_openssl_debug_flags}")
    message(STATUS "[OpenSSL]   source : ${openssl_SOURCE_DIR}")
    message(STATUS "[OpenSSL]   build  : ${openssl_BINARY_DIR}")

    execute_process(
        COMMAND
            "${PERL_EXECUTABLE}" "${openssl_SOURCE_DIR}/Configure"
            "${_openssl_configure_target}"
            -D__ANDROID_API__=${_api_level}
            ${_openssl_debug_flags}
            no-shared       # 정적 라이브러리만 빌드
            no-makedepend   # 빌드 속도 향상
        WORKING_DIRECTORY "${openssl_BINARY_DIR}"
        RESULT_VARIABLE   _configure_result
        OUTPUT_VARIABLE   _configure_output
        ERROR_VARIABLE    _configure_error
        ECHO_OUTPUT_VARIABLE
        ECHO_ERROR_VARIABLE
    )

    if (NOT _configure_result EQUAL 0)
        message(FATAL_ERROR
            "[OpenSSL] perl Configure 실패 (exit=${_configure_result}):\n"
            "${_configure_error}"
        )
    endif()

    message(STATUS "[OpenSSL] Configure 완료.")

    # -----------------------------------------------------------------------
    # Step 7. make 빌드 → libcrypto.a, libssl.a 생성
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

    if (CMAKE_HOST_WIN32)
        # Windows 호스트: NDK 번들 make.exe 사용
        #   NDK 번들: <ndk>/prebuilt/windows-x86_64/bin/make.exe
        #
        # Strawberry Perl의 c/bin 에는 sh.exe 등 Unix 도구가 포함되어 있어
        # OpenSSL Makefile의 SHELL 명령 실행에 사용된다.
        #   PERL_BIN_DIR    : .../tools/perl/perl/bin
        #   _strawberry_bin : .../tools/perl/c/bin   (sh.exe 위치)
        set(_ndk_make "${ANDROID_NDK_ROOT}/prebuilt/${_ndk_host_tag}/bin/make.exe")
        if (NOT EXISTS "${_ndk_make}")
            message(FATAL_ERROR
                "[OpenSSL] NDK make.exe를 찾을 수 없습니다:\n"
                "  ${_ndk_make}"
            )
        endif()
        message(STATUS "[OpenSSL] make : ${_ndk_make}")

        # PERL_BIN_DIR 에서 Strawberry 루트(c/bin) 경로 도출
        # perl.exe 경로: <root>/perl/bin/perl.exe → 두 단계 위가 <root>
        get_filename_component(_strawberry_perl_dir "${PERL_BIN_DIR}" DIRECTORY)
        get_filename_component(_strawberry_root     "${_strawberry_perl_dir}" DIRECTORY)
        set(_strawberry_bin "${_strawberry_root}/c/bin")

        add_custom_command(
            OUTPUT
                "${_openssl_crypto_lib}"
                "${_openssl_ssl_lib}"
            COMMAND ${CMAKE_COMMAND} -E env
                "ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT}"
                "PATH=${_ndk_llvm_bin}$<SEMICOLON>${PERL_BIN_DIR}$<SEMICOLON>${_strawberry_bin}$<SEMICOLON>$ENV{PATH}"
                "${_ndk_make}" -j${_cpu_count} build_libs
            WORKING_DIRECTORY "${openssl_BINARY_DIR}"
            COMMENT "[OpenSSL] Building OpenSSL with make -j${_cpu_count} build_libs..."
            USES_TERMINAL
            VERBATIM
        )
    else()
        # Linux / macOS 호스트: 시스템 make 직접 실행
        find_program(_make_exe
            NAMES make gmake
            DOC "make for Android OpenSSL build"
        )
        if (NOT _make_exe)
            message(FATAL_ERROR
                "[OpenSSL] make를 찾을 수 없습니다.\n"
                "시스템에 make 또는 gmake가 설치되어 있는지 확인하세요."
            )
        endif()
        message(STATUS "[OpenSSL] make : ${_make_exe}")

        add_custom_command(
            OUTPUT
                "${_openssl_crypto_lib}"
                "${_openssl_ssl_lib}"
            COMMAND ${CMAKE_COMMAND} -E env
                "ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT}"
                "PATH=${_ndk_llvm_bin}:${PERL_BIN_DIR}:$ENV{PATH}"
                "${_make_exe}" -j${_cpu_count} build_libs
            WORKING_DIRECTORY "${openssl_BINARY_DIR}"
            COMMENT "[OpenSSL] Building OpenSSL with make -j${_cpu_count} build_libs..."
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
    # IMPORTED 정적 라이브러리 타겟 생성
    # Android에서는 ws2_32/crypt32 같은 Windows 전용 링크 불필요
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

    # 표준 네임스페이스 별칭
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
        "[OpenSSL] 지원하지 않는 빌드 조합: OS=${TARGET_OS}, Compiler=${TARGET_COMPILER}"
    )
endif()
