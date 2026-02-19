function(detectTargetArchitecture OUT_VAR)

    if (ANDROID)
        set(_arch "${ANDROID_ABI}")
    else()
        set(_arch "${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    string(TOLOWER "${_arch}" _arch)

    if (_arch MATCHES "x86_64|amd64")
        set(result "x64")

    elseif (_arch MATCHES "^i[3-6]86$|x86")
        set(result "x86")

    elseif (_arch MATCHES "aarch64|arm64")
        set(result "arm64")

    elseif (_arch MATCHES "^arm")
        set(result "arm")

    else()
        message(FATAL_ERROR "Unsupported architecture: ${_arch}")
    endif()

    set(${OUT_VAR} "${result}" PARENT_SCOPE)

endfunction()