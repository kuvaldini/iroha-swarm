# iroha-swarm
Create configuration files for docker-compose to spawn a number of Iroha nodes.

## Common use cases
Generate and run iroha network of 4 nodes inside docker containers using auto-generated keys.
```
./iroha-swarm.sh 4
env IROHA_IMAGE=hyperledger/iroha:latest docker-compose up --force-recreate
```
NOTE: all nodes inside on docker-compose use the same postgres instance in a dedicated container.

Generate and run iroha network of 2 nodes inside docker containers using provided keys.
```
./iroha-swarm.sh --peers=iroha1::bddd58404d1315e0eb27902c5d7c8eb0602c16238f005773df406bc191308929:cc5013e43918bd0e5c4d800416c88bed77892ff077929162bb03ead40a745e88,iroha2::313a07e6384776ed95447710d15e59148473ccfc052a681317a72a69f2a49910:f101537e319568c765b2cc89698325604991dca57b9716b58016b253506cab70,
env IROHA_IMAGE=hyperledger/iroha:latest docker-compose up --force-recreate
```

Generate and run iroha network of 2 nodes locally
```
./iroha-swarm.sh 2 --localhost
initdb -Upostgres /path/to/db
postgres -D/path/to/db
env IROHAD=/path/to/irohad ./run-irohas.sh 2
```

## The output
`iroha-swarm` generates `docker-compose.yaml`, `genesis.block`, `irohaX.config`, and `irohaX.priv`,`.pub` files.
```
> ls
docker-compose.yaml iroha1.config       iroha1.pub          iroha2.priv         iroha3.config       iroha3.pub          iroha4.priv
genesis.block       iroha1.priv         iroha2.config       iroha2.pub          iroha3.priv         iroha4.config       iroha4.pub
```

`iroha-swarm --localhost` generates `run-irohas.sh`, `genesis.block`, `irohaX.config`, and `irohaX.priv`,`.pub` files.



## TODO
* rocksdb
* assert works fine --local
* docker-compose.yml:volumes: auto-extend

## Hints

### Initialize local Postgres database
When use `iroha-swarm --without-docker`
```
initdb -Upostgres /path/to/db
postgres -D/path/to/db
```
optional arguments `-d1` to debug and `-p5432` to set listening port.

### For usage and help see [iroha-swarm.sh](./iroha-swarm.sh)

### Troubleshooting
If you got unexpected behaivor or error please clean up containers and volumes. See [`./clean-start.sh`](./clean-start.sh).  
At any time you are wellcome to ask questions in [telegram chat](https://t.me/hyperledgeriroha) and on stackoverflow with tag hyperledger/iroha.
