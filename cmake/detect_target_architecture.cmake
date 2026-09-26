function(detectTargetArchitecture OUT_VAR)

    if (ANDROID)
        set(_arch "${ANDROID_ABI}")
    elseif (APPLE AND CMAKE_OSX_ARCHITECTURES)
        # Honor an explicit target arch so x86_64 can be cross-built on an Apple
        # Silicon host (and vice versa). A universal (multi-arch) request is
        # ambiguous here — OpenSSL builds one arch at a time — so reject it.
        list(LENGTH CMAKE_OSX_ARCHITECTURES _osx_arch_count)
        if (_osx_arch_count GREATER 1)
            message(FATAL_ERROR
                "Multiple CMAKE_OSX_ARCHITECTURES (${CMAKE_OSX_ARCHITECTURES}) are not "
                "supported — there is no universal binary. Build one architecture at a time.")
        endif()
        set(_arch "${CMAKE_OSX_ARCHITECTURES}")
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