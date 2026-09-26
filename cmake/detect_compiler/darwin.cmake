function(detectDarwinTargetCompiler OUT_VAR)

    # macOS ships Clang via the Xcode Command Line Tools. CMake reports its
    # compiler id as "AppleClang" (and plain "Clang" for an LLVM/Homebrew clang),
    # so match both. Either way we treat it as clang for the OpenSSL Configure.
    if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")

        set(result "clang")

    else()

        message(FATAL_ERROR
            "Unsupported macOS compiler: ${CMAKE_CXX_COMPILER_ID}\n"
            "Install the Xcode Command Line Tools with:\n"
            "  xcode-select --install"
        )

    endif()

    set(${OUT_VAR} "${result}" PARENT_SCOPE)

endfunction()
