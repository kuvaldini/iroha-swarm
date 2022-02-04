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
### For docker-compose
`iroha-swarm` generates `docker-compose.yaml`, `genesis.block`, `irohaX.config`, and `irohaX.priv`,`.pub` files.
```
> ls
docker-compose.yaml iroha1.config       iroha1.pub          iroha2.priv         iroha3.config       iroha3.pub          iroha4.priv
genesis.block       iroha1.priv         iroha2.config       iroha2.pub          iroha3.priv         iroha4.config       iroha4.pub
```
stdout
```
2 nodes ready to run inside containers:
  1. iroha1:10001 pub=bdd... priv=cc5...
  2. iroha1:10001 pub=313... priv=f10...
According to config files
  Metrics will listen at ports:  7001 7002
  Torii will listen at ports:  50051 50052
To run iroha nodes on current host do:
   env IROHAD=/path/to/irohad ./run-irohas.sh 2
```

### For local run
`iroha-swarm --localhost` generates `run-irohas.sh`, `genesis.block`, `irohaX.config`, and `irohaX.priv`,`.pub` files.
stdout
```
2 nodes ready to run on localhost:
  1. localhost:10001 pub=bdd... priv=cc5...
  2. localhost:10002 pub=313... priv=f10...
According to docker-compose.yaml
  Metrics exposed from docker to local ports:  7001 7002
  Torii exposed from docker to local ports:  50051 50052
To run iroha nodes in containers do:
   env IROHA_IMAGE=hyperledger/iroha:latest docker-compose up --force-recreate
```

## Usage
For details please review source [iroha-swarm.sh](./iroha-swarm.sh)
```
iroha-swarm for hyperledger/iroha
Produce configuration files to run Hyperledger/Iroha network of multiple instances.
  https://github.com/kuvaldini/iroha-swarm
USAGE:
   iroha-swarm [options...]
OPTIONS:
   -l|--local|--localhost               Produce config files for LOCAL run, default is docker
   --docker                             Produce config files to run inside DOCKER containers, this is default
   --peers_count=*                      Number of peers in Iroha network, keys are taken from embedded example list. JUST FOR A QUICK START.
   --peers=*                            Define peers in format host1:port1:pubkey1:privkey1,host2:port2:pubkey2:privkey2,...
   --peers_from=*                       Read --peers from file
   --rocksdb|--rocks                    Use database RocksDB
   --postgres|--postgresdb              Use database Postgres
   --dbtype=*                           Database type: rocksdb or postrges, default:postgres. Read the docs.
   --rocksdb_path=*                     Path to RocksDB directory
   --postgres_host=*|--postgres_port=*  Configure PostgresDB, default localhost:5432, see https://iroha.readthedocs.io/en/develop/configure/index.html
   --base_torii_port=*                  Base Torii port to access Iroha API, default 50050
   --help                               Print this usage message
   -x|--trace|--xtrace                  Trace commands as bash -x
   +x|--no-trace|--no-xtrace            NOT trace as bash +x
```

## TODO
* automated tests on GitHub Actions
* add graphana and prometheus

## Hints

### Initialize local Postgres database
When use `iroha-swarm --without-docker`
```
initdb -Upostgres /path/to/db
postgres -D/path/to/db
```
optional arguments `-d1` to debug and `-p5432` to set listening port.

### Troubleshooting
If you got unexpected behaivor or error please clean up containers and volumes. See [`./clean-start.sh`](./clean-start.sh).
At any time you are wellcome to ask questions in [telegram chat](https://t.me/hyperledgeriroha) and on stackoverflow with tag hyperledger/iroha.
