#!/bin/bash
set -euo pipefail

export VAULT_TOKEN='s.iYqhMo3SNKDhuVCzATkyB3ra'
export VAULT_ADDR='http://localhost:8200'
export DOMAIN_NAME='mainflux.com'
export PERMITED_DNS_DOMAINS='mainflux.ml,www.mainflux.ml,mainflux.com,www.mainflux.com,mainflux.ga,www.mainflux.ga,mirkash.ml,www.mirkash.ml,kulash,www.kulash.com'
export OU='Mainflux Cloud'
export ORG='Mainflux'
export COUNTRY='Serbia'
export LOC='BG'
export NAME='mainflux'
export ROLE_NAME='mainflux'
rm -rf data
mkdir data

# Create pki.
# in vault.hcl 
# # Work with pki secrets engine
# path "pki*" {
#  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
# }
vault login ${VAULT_TOKEN}
# vault secrets enable -path pki_${NAME} pki
# vault secrets tune -max-lease-ttl=87600h pki_${NAME}

# # # Add role to secret.
# vault write pki_${NAME}/roles/${NAME} \
#     allow_any_name=true \
#     max_ttl="4300h" \
#     default_ttl="4300h" \
#     generate_lease=true

# # Generate root CA certificate
# vault write  -format=json pki_${NAME}/root/generate/exported \
#         common_name="\"$DOMAIN_NAME CA Root\""\
#         permitted_dns_domains="\"$PERMITED_DNS_DOMAINS\"" \
#         ou="\"$OU\""\
#         organization="\"$ORG\"" \
#         country="\"$COUNTRY\""\
#         locality="\"$LOC\"" \
#         ttl=87600h | tee >(jq -r .data.certificate >data/${NAME}_ca.crt) >(jq -r .data.issuing_ca >data/${NAME}_issuing_ca.crt) >(jq -r .data.private_key >data/${NAME}_ca.key)
# # Generate Intermediate CA

NAME_PKI_INT_PATH="pki_int_$NAME"
vault secrets enable -path=${NAME_PKI_INT_PATH} pki

vault secrets tune -max-lease-ttl=43800h ${NAME_PKI_INT_PATH}

       
# Generate intermediate CSR
vault write -format=json ${NAME_PKI_INT_PATH}/intermediate/generate/exported \
 common_name="$DOMAIN_NAME Intermediate Authority" | tee >(jq -r .data.csr >data/${NAME}_int.csr) >(jq -r .data.private_key >data/${NAME}_int.key)

# Sign intermediate CSR
vault write -format=json pki_${NAME}/root/sign-intermediate \
 csr=@data/${NAME}_int.csr | tee >(jq -r .data.certificate >data/${NAME}_int.crt) >(jq -r .data.issuing_ca >data/${NAME}_int_issuing_ca.crt)

# Inject Intermediate Certificate
vault write ${NAME_PKI_INT_PATH}/intermediate/set-signed certificate=@data/${NAME}_int.crt

# Generate intermediate certificate bundle
cat data/${NAME}_int.crt data/${NAME}_ca.crt >data/${NAME}_int_bundle.crt



# Set URLs for CRL and issuing.
vault write ${NAME_PKI_INT_PATH}/config/urls \
    issuing_certificates="$VAULT_ADDR/v1/${NAME_PKI_INT_PATH}/ca" \
    crl_distribution_points="$VAULT_ADDR/v1/${NAME_PKI_INT_PATH}/crl"


# Add role
vault write ${NAME_PKI_INT_PATH}/roles/${ROLE_NAME} \
        allowed_domains=${PERMITED_DNS_DOMAINS} \
        allow_subdomains=true \
        allow_any_name=true \
        max_ttl="720h"

