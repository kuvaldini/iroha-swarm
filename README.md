# iroha-swarm
Create configuration files for docker-compose to spawn a number of iroha nodes.

## TODO
* rocksdb
* assert works fine --local
* docker-compose.yml:volumes: auto-extend

### Initialize local Postgres database
When use `iroha-swarm --without-docker`
```
initdb -Upostgres /path/to/db
postgres -D/path/to/db
```
optional arguments `-d1` to debug and `-p5432` to set listening port.
