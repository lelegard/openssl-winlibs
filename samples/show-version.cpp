#include <iostream>
#include <openssl/opensslv.h>
#include <openssl/evp.h>
#include <openssl/err.h>

int main()
{
    std::cout << "OpenSSL version: " << OpenSSL_version(OPENSSL_FULL_VERSION_STRING) << std::endl;
    std::cout << "OpenSSL CPU info: " << OpenSSL_version(OPENSSL_CPU_INFO) << std::endl;
}
