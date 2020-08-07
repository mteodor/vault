#!/bin/bash
set -euo pipefail

export VAULT_TOKEN='s.bUPN41KMOEw7g6zZ96lfYzxk'
export VAULT_ADDR='http://localhost:8100'
export DOMAIN_NAME='mt-global.ml'
export OU='Mirko Cloud'
export ORG='Mirko Company'
export COUNTRY='Serbia'
export LOC='BG'
export NAME='mainflux5'
export ROLE_NAME='mainflux5'
export MAINFLUX_DIR='../'
#rm -rf data
#mkdir data

# Create pki.
# in vault.hcl 
# # Work with pki secrets engine
# path "pki*" {
#  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
# }
vault login ${VAULT_TOKEN}
vault secrets enable -path pki_${NAME} pki
vault secrets tune -max-lease-ttl=87600h pki_${NAME}

# # Add role to secret.
vault write pki_${NAME}/roles/${NAME} \
    allow_any_name=true \
    max_ttl="4300h" \
    default_ttl="4300h" \
    generate_lease=true

# Generate root CA certificate
echo "Generate root CA certificate"
vault write  -format=json pki_${NAME}/root/generate/exported \
        common_name="\"$DOMAIN_NAME CA Root\""\
        ou="\"$OU\""\
        organization="\"$ORG\"" \
        country="\"$COUNTRY\""\
        locality="\"$LOC\"" \
        ttl=87600h | tee >(jq -r .data.certificate >data/${NAME}_ca.crt) >(jq -r .data.issuing_ca >data/${NAME}_issuing_ca.crt) >(jq -r .data.private_key >data/${NAME}_ca.key)

# Create Intermediate CA PKI
echo "Create Intermediate CA PKI"
NAME_PKI_INT_PATH="pki_int_$NAME"
vault secrets enable -path=${NAME_PKI_INT_PATH} pki
vault secrets tune -max-lease-ttl=43800h ${NAME_PKI_INT_PATH}

# Generate Intermediate CA       
# Generate intermediate CSR
echo "Generate intermediate CSR"
vault write -format=json ${NAME_PKI_INT_PATH}/intermediate/generate/exported \
 common_name="$DOMAIN_NAME Intermediate Authority" | tee >(jq -r .data.csr >data/${NAME}_int.csr) >(jq -r .data.private_key >data/${NAME}_int.key)

# Sign intermediate CSR
echo "Sign intermediate CSR"
vault write -format=json pki_${NAME}/root/sign-intermediate \
 csr=@data/${NAME}_int.csr | tee >(jq -r .data.certificate >data/${NAME}_int.crt) >(jq -r .data.issuing_ca >data/${NAME}_int_issuing_ca.crt)

# Inject Intermediate Certificate
echo "Inject Intermediate Certificate"
vault write ${NAME_PKI_INT_PATH}/intermediate/set-signed certificate=@data/${NAME}_int.crt

# Generate intermediate certificate bundlee
echo "Generate intermediate certificate bundle"
cat data/${NAME}_int.crt data/${NAME}_ca.crt >data/${NAME}_int_bundle.crt


# Set URLs for CRL and issuing.
echo "Set URLs for CRL and issuing."
vault write ${NAME_PKI_INT_PATH}/config/urls \
    issuing_certificates="$VAULT_ADDR/v1/${NAME_PKI_INT_PATH}/ca" \
    crl_distribution_points="$VAULT_ADDR/v1/${NAME_PKI_INT_PATH}/crl"


# Add role
vault write ${NAME_PKI_INT_PATH}/roles/${ROLE_NAME} \
        allow_subdomains=true \
        allow_any_name=true \
        max_ttl="720h"

# Generate server certificate
vault write -format=json ${NAME_PKI_INT_PATH}/issue/${ROLE_NAME} \
    common_name="$DOMAIN_NAME" ttl="8670h"  | tee >(jq -r .data.certificate >data/${DOMAIN_NAME}.crt) >(jq -r .data.private_key >data/${DOMAIN_NAME}.key)


echo "Copying certificate files"

cp -v data/${DOMAIN_NAME}.crt   ${MAINFLUX_DIR}/docker/ssl/certs/mainflux-server.crt
cp -v data/${DOMAIN_NAME}.key   ${MAINFLUX_DIR}/docker/ssl/certs/mainflux-server.key
cp -v data/${NAME}_int_bundle.crt ${MAINFLUX_DIR}/docker/ssl/bundle.pem 
cp -v data/${NAME}_int.crt ${MAINFLUX_DIR}/docker/ssl/certs/ca.crt 
cp -v data/${NAME}_int.key ${MAINFLUX_DIR}/docker/ssl/certs/ca.key

exit 0

