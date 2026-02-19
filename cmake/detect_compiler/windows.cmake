function(detectWindowsTargetCompiler OUT_VAR)
    if (MSVC)
        set(result "msvc")
    elseif (MINGW)
        set(result "mingw")
    else()
        message(FATAL_ERROR
            "Unsupported Windows compiler.\n"
            "Detected CMAKE_CXX_COMPILER_ID: ${CMAKE_CXX_COMPILER_ID}\n"
            "MSVC: ${MSVC}\n"
            "MINGW: ${MINGW}"
        )
    endif()

    set(${OUT_VAR} "${result}" PARENT_SCOPE)
    
endfunction()