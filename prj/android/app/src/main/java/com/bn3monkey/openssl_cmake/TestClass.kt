package com.bn3monkey.openssl_cmake

class TestClass {
    companion object {
        // Used to load the 'openssl_cmake' library on application startup.
        init {
            System.loadLibrary("openssl_cmake_android")
        }
    }

    external fun main()
}