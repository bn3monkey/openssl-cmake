cmake_minimum_required(VERSION 3.15)

project(openssl-cmake-windows C CXX)

add_subdirectory(../../ ${CMAKE_CURRENT_BINARY_DIR}/origin)

add_executable(testapp
    main.cpp)

target_link_libraries(testapp
    OpenSSL::SSL
    OpenSSL::Crypto)