# cmake/acquire_perl.cmake
# 빌드 환경에 맞는 Perl 인터프리터를 획득한다.
#
# 필요 변수:
#   TARGET_OS       - 타겟 OS (Windows, Linux, Android)
#   TARGET_COMPILER - 타겟 컴파일러 (msvc, mingw, gcc, clang)
#
# 출력 변수 (플랫폼별 cmake에서 설정):
#   PERL_EXECUTABLE - perl 실행 파일 전체 경로
#   PERL_BIN_DIR    - perl 실행 파일이 위치한 디렉토리

if ("${TARGET_OS}" STREQUAL "Windows")
    if ("${TARGET_COMPILER}" STREQUAL "msvc")
        # MSVC: Strawberry Perl portable 다운로드
        include(cmake/acquire_perl/msvc.cmake)
    elseif ("${TARGET_COMPILER}" STREQUAL "mingw")
        # MinGW: MSYS2 설치 후 pacman으로 Perl 획득
        include(cmake/acquire_perl/mingw.cmake)
    else()
        message(FATAL_ERROR "[Perl] Unsupported Windows compiler: ${TARGET_COMPILER}")
    endif()

elseif ("${TARGET_OS}" STREQUAL "Linux")
    include(cmake/acquire_perl/linux.cmake)

elseif ("${TARGET_OS}" STREQUAL "Android")
    include(cmake/acquire_perl/android.cmake)

else()
    message(FATAL_ERROR "[Perl] Unsupported TARGET_OS: ${TARGET_OS}")
endif()

if (NOT PERL_EXECUTABLE)
    message(FATAL_ERROR "[Perl] PERL_EXECUTABLE is not set after include.")
endif()
