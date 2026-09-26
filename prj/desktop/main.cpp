#include <openssl/ssl.h>
#include <openssl/crypto.h>
#include <openssl/evp.h>
#include <openssl/err.h>

#include <iostream>
#include <array>
#include <cstring>


bool test_crypto()
{
    const char* message = "TLS Test";
    std::array<unsigned char, 32> digest{};

    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    if (!ctx)
        return false;

    bool ok =
        EVP_DigestInit_ex(ctx, EVP_sha256(), nullptr) &&
        EVP_DigestUpdate(ctx, message, std::strlen(message)) &&
        EVP_DigestFinal_ex(ctx, digest.data(), nullptr);

    EVP_MD_CTX_free(ctx);
    return ok;
}

bool test_ssl_context_tls12()
{
    const SSL_METHOD* method = TLS_method();
    if (!method)
        return false;

    SSL_CTX* ctx = SSL_CTX_new(method);
    if (!ctx)
        return false;

    bool ok =
        SSL_CTX_set_min_proto_version(ctx, TLS1_2_VERSION) &&
        SSL_CTX_set_max_proto_version(ctx, TLS1_2_VERSION);

    if (ok)
    {
        int min = SSL_CTX_get_min_proto_version(ctx);
        int max = SSL_CTX_get_max_proto_version(ctx);

        ok = (min == TLS1_2_VERSION && max == TLS1_2_VERSION);
    }

    SSL_CTX_free(ctx);
    return ok;
}

int main()
{
    OPENSSL_init_ssl(0, nullptr);

    bool crypto_ok = test_crypto();
    bool ssl_ok = test_ssl_context_tls12();

    if (!crypto_ok || !ssl_ok)
    {
        ERR_print_errors_fp(stderr);
        std::cerr << "OpenSSL TLS self-check FAILED\n";
        return 1;
    }

    std::cout << "OpenSSL TLS self-check PASSED\n";
    return 0;
}