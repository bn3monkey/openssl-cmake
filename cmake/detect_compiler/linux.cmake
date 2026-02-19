function(detectLinuxTargetCompiler OUT_VAR)

    set(${OUT_VAR} "${result}" PARENT_SCOPE)

        # Pre-check compiler existence
    find_program(GCC_PATH gcc)
    find_program(CLANG_PATH clang)

    if (NOT GCC_PATH AND NOT CLANG_PATH)

        set(DISTRO "unknown")

        if (EXISTS "/etc/os-release")
            file(READ "/etc/os-release" OS_RELEASE_CONTENT)
            string(REGEX MATCH "ID=([a-zA-Z0-9]+)"
                _ "${OS_RELEASE_CONTENT}"
            )
            set(DISTRO "${CMAKE_MATCH_1}")
        endif()

        if (DISTRO STREQUAL "ubuntu" OR DISTRO STREQUAL "debian")

            message(FATAL_ERROR
                "\n[ERROR] No GCC or Clang detected.\n"
                "Install compiler with:\n"
                "  sudo apt update\n"
                "  sudo apt install build-essential\n"
            )

        elseif (DISTRO STREQUAL "fedora")

            message(FATAL_ERROR
                "\n[ERROR] No GCC or Clang detected.\n"
                "Install compiler with:\n"
                "  sudo dnf install gcc gcc-c++ make\n"
            )

        elseif (DISTRO STREQUAL "arch")

            message(FATAL_ERROR
                "\n[ERROR] No GCC or Clang detected.\n"
                "Install compiler with:\n"
                "  sudo pacman -S base-devel\n"
            )

        else()

            message(FATAL_ERROR
                "\n[ERROR] No GCC or Clang detected.\n"
                "Please install GCC or Clang using your package manager.\n"
            )

        endif()

    endif()

    # Detect actual compiler used by CMake
    if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")

        set(result "gcc")

    elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")

        set(result "clang")

    else()

    message(FATAL_ERROR
        "Unsupported Linux compiler: ${CMAKE_CXX_COMPILER_ID}"
    )

    endif()
    
    set(${OUT_VAR} "${result}" PARENT_SCOPE)

endfunction()