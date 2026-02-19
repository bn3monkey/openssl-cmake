function(detectAndroidTargetCompiler OUT_VAR)
    if (NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        message(FATAL_ERROR
            "Android NDK must use Clang.\n"
            "Detected: ${CMAKE_CXX_COMPILER_ID}"
        )
    endif()

    set(${OUT_VAR} "clang" PARENT_SCOPE)

endfunction()