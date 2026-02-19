# For more information about using CMake with Android Studio, read the
# documentation: https://d.android.com/studio/projects/add-native-code.html.
# For more examples on how to use CMake, see https://github.com/android/ndk-samples.

# Sets the minimum CMake version required for this project.
cmake_minimum_required(VERSION 3.22.1)

project(openssl_cmake_android C CXX)

# .. main
# ../.. src
# ../../.. app
# ../../../.. android
# ../../../../.. prj
# ../../../../../..
message(STATUS "CMAKE SOURCE DIR = ${CMAKE_SOURCE_DIR}")
message(STATUS "CMAKE CURRENT SOURCE DIR = ${CMAKE_CURRENT_SOURCE_DIR}")
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../" ${CMAKE_CURRENT_BINARY_DIR}/origin)