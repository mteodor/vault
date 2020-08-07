# vault

This is `vault` service deployment to be used with `Mainflux` for development purposes

How to start:

Get the Mainflux code
```
git clone https://github.com/mainflux/mainlux
cd mainflux
git clone https://github.com/mteodor/vault
cd vault
```

First we need to build the image:

```
docker-compose -f docker-compose.yml up -d --build
```

Image is based on alpine but in addition there is a bash added.

Than when the vault is started we need to perform the initialision
From within a docker container 

```
docker exec -it vault_vault_1 bash
```

```
bash-4.4# vault operator init
Unseal Key 1: Ay0YZecYJ2HVtNtXfPootXK5LtF+JZoDmBb7IbbYdLBI
Unseal Key 2: P6hb7x2cglv0p61jdLyNE3+d44cJUOFaDt9jHFDfr8Df
Unseal Key 3: zSBfDHzUiWoOzXKY1pnnBqKO8UD2MDLuy8DNTxNtEBFy
Unseal Key 4: 5oJuDDuMI0I8snaw/n4VLNpvndvvKi6JlkgOxuWXqMSz
Unseal Key 5: ZhsUkk2tXBYEcWgz4WUCHH9rocoW6qZoiARWlkE5Epi5

Initial Root Token: s.V2hdd00P4bHtUQnoWZK2hSaS

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated master key. Without at least 3 key to
reconstruct the master key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
bash-4.4

```

Use 3 out of five keys presented and put it into .env file and than start the composition again
`Vault` should be in unsealed state ( take a note that this is not recommended in terms of security, this is deployment for development)
A real production deployment can use `Vault` auto unseal mode where vault gets unseal keys from some 3rd party KMS ( on AWS for example)

Now edit the `set-pki.sh` script:

```
export VAULT_TOKEN='s.bUPN41KMOEw7g6zZ96lfYzxk'
export VAULT_ADDR='http://localhost:8100'
export DOMAIN_NAME='mainflux.com'
export OU='Mainflux Cloud'
export ORG='Mainflux Company'
export COUNTRY='Serbia'
export LOC='BG'
export NAME='mainflux5'
export ROLE_NAME='mainflux5'
export MAINFLUX_DIR='../'
```

Execute script 
```
./set-pki.sh
```
Script will generate root certificate, intermediate certificate and HTTPS server certificate and copy it into the deployment directory.



