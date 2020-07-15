#!/bin/bash


vault server -config=/vault/config/vault-config.json&
sleep 2

echo "unseal vault"
vault operator unseal ${VAULT_UNSEAL_KEY_1}
vault operator unseal ${VAULT_UNSEAL_KEY_2}
vault operator unseal ${VAULT_UNSEAL_KEY_3}

# this is stupid way not to exit from the shell script
# but I need to start the server and then to execute unseal
# sequence and after that if shell script exits container exits
while :
do
	sleep 10000
done

