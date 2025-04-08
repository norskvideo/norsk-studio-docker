#!/usr/bin/env bash
set -eo pipefail
cd "${0%/*}"
mkdir -p certs
cd certs

# Private key
openssl ecparam -genkey -name secp384r1 -out nginx.ec.key

# CSR
openssl req -new -sha256 -key nginx.ec.key -subj "/CN=devops/C=BM/ST=Bermudian/L=Bermudian/O=Org/OU=IT" -out nginx.ec.csr

# Certificate
openssl req -x509 -sha256 -days 3650 -copy_extensions none -key nginx.ec.key -in nginx.ec.csr -out nginx.ec.crt

# We no longer need the CSR
rm nginx.ec.csr

# nginx conf
# ssl_certificate .../nginx.ec.crt;
# ssl_certificate_key .../nginx.ec.key;
