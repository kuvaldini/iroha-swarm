#!/usr/bin/env bash
set -eEuo pipefail
shopt -s inherit_errexit
shopt -s lastpipe
shopt -s expand_aliases

readonly script_dir=$(dirname $(realpath "$0"))

readonly VERSION=master-c14-g0ed425b
readonly VERSION_NPM=1.14.0

function echomsg      { echo $'\e[0;37m'"$@"$'\e[0m'; }
# alias echoinfo=echomsg
function echonote { >&2 echo $'\e[0;37m'NOTE$'\e[0m' "$@"; }
function echodbg  { >&2 echo $'\e[0;36m'"$@"$'\e[0m'; }
function echowarn { >&2 echo $'\e[0;33m'WARNING$'\e[0m' "$@"; }
function echoerr  { >&2 echo $'\e[0;31m'ERROR$'\e[0m' "$@"; }
function fatalerr { >&2 echoerr "$@"; exit 1; }

if test `uname` == Darwin ;then
   alias sed=gsed
   alias grep=ggrep
   alias find=gfind
   alias date=gdate
   alias cp=gcp
   alias mv=gmv
   alias ls=gls
   alias mktemp=gmktemp
   alias readlink=greadlink
fi

function OnErr { caller | { read lno file; echoerr ">ERR in $file:$lno,  $(sed -n ${lno}p $file)" >&2; };  }
trap OnErr ERR

is_sourced(){
   [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

var_is_set(){
   declare -rn var=$1
   ! test -z ${var+x}
}
var_is_set_not_empty(){
   declare -rn var=$1
   ! test -z ${var:+x}
}
var_is_unset(){
   declare -rn var=$1
   test -z ${var+x}
}
var_is_unset_or_empty(){
   declare -rn var=$1
   test -z ${var:+x}
}
var_is_unset_or_empty_multi(){
   while true; do
      if var_is_unset_or_empty $1
      then return $?
      fi
      if shift
      then continue
      else return 0
      fi
   done
}

function --version {
   echo "git-rev-label v$VERSION_NPM
   $VERSION
   https://gitlab.com/kyb/git-rev-label"
}
-V(){ echo "git-rev-label v$VERSION_NPM"; }
function --rev-label {
   echo "$VERSION"
}
--rev(){ --rev-label "$@"; }
--version-npm(){ echo $VERSION_NPM; }
--npm-version(){ --version-npm "$@"; }

set_with_warn(){
   local varname=$1
   shift
   var_is_set $varname && [[ "${!varname}" != "$@" ]] && echowarn "!!! $varname already set to '${!varname}'. Overriding with '$@'"
   declare -g $varname="$@"
}
set_with_warn_from_arg(){
   local varname=${1%%=*}; varname=${varname#--}
   var_is_set $varname  && echowarn "!!! $varname already set to '${!varname}'. Overriding"
   declare -g $varname="${1#*=}"
}
test_var_equals(){
   declare -n var=$1
   shift
   test "${var:-}" = "$@"
}
test_yes(){
   test_var_equals $1 yes
}
test_no(){
   ! test_var_equals $1 yes
}
assert_is_port(){
   x=$1
   if ! printf %d "$x" &>/dev/null && ((x>0 && x<=65535))
   then fatalerr "Peer's $i port must be non-zero 16bit number, got '$x'"
   fi
}

while [[ $# > 0 ]] ;do
   case $1 in
      ## CMDLINE OPTIONS BEGIN
      -l|--local|--localhost)  ##              Produce config files for LOCAL run, default is docker
         set_with_warn use_localhost yes ;;
      --docker)  ##                            Produce config files to run inside DOCKER containers, this is default
         set_with_warn use_localhost no ;;
      --peers_count=*)  ##                     Number of peers in Iroha network, keys are taken from embedded example list. JUST FOR A QUICK START.
         set_with_warn_from_arg "$1" ;;
      --peers=*)  ##                           Define peers in format host1:port1:pubkey1:privkey1,host2:port2:pubkey2:privkey2,...
         set_with_warn_from_arg "$1" ;;
         #set_with_warn peers "${1##--peers=}" ;;
      --peers_from=*)  ##                      Read --peers from file
         set_with_warn peers "$(cat ${1##--peers_from=})" ;;  ## to be well tested
      --rocksdb|--rocks)  ##                   Use database RocksDB
         set_with_warn dbtype rocksdb ;;
      --postgres|--postgresdb)  ##             Use database Postgres
         set_with_warn dbtype postgres ;;
      --dbtype=*)  ##                          Database type: rocksdb or postrges, default:postgres. Read the docs.
         set_with_warn dbtype "${1##--dbtype=}" ;;
      --rocksdb_path=*)  ##                    Path to RocksDB directory
         set_with_warn_from_arg "$1" ;;
      --postgres_host=*|--postgres_port=*)  ## Configure PostgresDB, default localhost:5432, see https://iroha.readthedocs.io/en/develop/configure/index.html
         set_with_warn_from_arg "$1" ;;
      --base_torii_port=*)  ##                 Base Torii port to access Iroha API, default 50050
         set_with_warn_from_arg "$1" ;;
      --help)  ##                              Print this usage message
         echo "iroha-swarm for hyperledger/iroha"
         echo 'Produce configuration files to run Hyperledger/Iroha network of multiple instances.'
         echo "  https://github.com/kuvaldini/iroha-swarm"
         echo 'USAGE:'
         echo "   iroha-swarm [options...]"
         echo 'OPTIONS:'
         awk '/## CMDLINE OPTIONS BEGIN/{flag=1; next} /## CMDLINE OPTIONS END/{flag=0} flag' "${BASH_SOURCE[0]}" |
            sed -nE 's,^\s*([-+]+.*)\).*(##(.*)),   \1 \3,p'
         exit 0
         ;;
      -x|--trace|--xtrace)  ##                 Trace commands as bash -x
         # PS4=$'\e[32m+ '
         set -x ;;
      +x|--no-trace|--no-xtrace)  ##           NOT trace as bash +x
         set +x ;;
      # --debug|-D)  ##                          Enable echodbg messages, also works if DEBUG is set in environment
      #    DEBUG=y ;;
      # --no-debug)  ##                          Disable echodbg messages, also works if DEBUG is set in environment
      #    unset DEBUG ;;
      ## CMDLINE OPTIONS END
      -*|--*)
         fatalerr "!!! Unknown option '$1'" ;;
      *)
         fatalerr "!!! Unhandled non-option argument '$1'" ;;
   esac
   shift
done

dbtype=${dbtype:-postgres}
case "$dbtype" in (postgres|rocksdb);; (*) fatalerr "Expected dbtype postgres or rocksdb. Use --postgres or --rocks.";; esac

readonly rocksdb_path=${rocksdb_path:-/opt/iroha_rocksdb}

{ var_is_unset_or_empty peers_count && var_is_unset_or_empty peers; } ||
{ var_is_set_not_empty peers_count && var_is_set_not_empty peers; } &&
   fatalerr "Only one and at least one of --peers or --peers_count or --peers_from must be set."

if test_no use_localhost ;then
   var_is_set_not_empty postgres_host && echowarn "postgres_host ignored for iroha-swarm in docker"
   var_is_set_not_empty postgres_port && echowarn "postgres_port ignored for iroha-swarm in docker"
fi

readonly PRIV_KEYS=(
   cc5013e43918bd0e5c4d800416c88bed77892ff077929162bb03ead40a745e88
   f101537e319568c765b2cc89698325604991dca57b9716b58016b253506cab70
   7e65d1c440bc45363f01c4218bf0e65e0d8c1d46a4f5b82b29132d4edce1329c
   f4309e61f735103274854e34375c63436c8b38fa6e74094e6be96c401bfc0f12
)
readonly PUB_KEYS=(
   bddd58404d1315e0eb27902c5d7c8eb0602c16238f005773df406bc191308929
   313a07e6384776ed95447710d15e59148473ccfc052a681317a72a69f2a49910
   8da2d43a41008a79206be292a8298315b602591a2b85f74c3c0bbb9372211373
   8f014fa2b7832d25458ae68a541d51a1044f87afc5513967fda16e3728e68f61
)
test ${#PUB_KEYS[@]} -eq ${#PRIV_KEYS[@]}

## For quick start, if --peers not set, fill peers parameters from prestored keys
var_is_unset_or_empty peers && {
   test $peers_count -le ${#PUB_KEYS[@]}
   for (( i=1; i<=$peers_count; ++i )); do
      if test_yes use_localhost ;then
         host= #localhost
         port=$((10000+i))
      else
         host=iroha$i
         port= #10001
      fi
      peers+=$host:$port:${PUB_KEYS[$((i-1))]}:${PRIV_KEYS[$((i-1))]},
   done;
}
readonly peers_count=${peers_count:=${#PUB_KEYS[@]}}

## Prepare docker-compose.yaml
if test_no use_localhost ;then
   cp $script_dir/docker-compose.base.yml docker-compose.yaml
   case $dbtype in
      rocksdb)
         yq e '.x-iroha-base.entrypoint="irohad" |
               .x-iroha-base.command="--genesis_block genesis.block --config config.docker --keypair_name iroha.tech" |
               del(.x-iroha-base.environment.KEY) |
               del(.x-iroha-base.depends_on) |
               del(.volumes) |
               del(.services.irpsql)' -i docker-compose.yaml
         ;;
      postgres)
         yq e 'del(.volumes) | .volumes.postgres_data=null' -i docker-compose.yaml
         ;;
   esac
fi

## Parse peers and fill files
peers_out=
JSON_peers=
declare -i i=0
peers="$(echo "$peers" | sed -E 's/,+$//')",

echo "$peers" |
 while IFS=: read -d, host port pubkey privkey rest ;do
   [[ -n "$rest" ]] && fatalerr "Unexpected rest '$rest'"

   ((++i))

   ## Keys to files: Validate and write keys to files
   test ${#pubkey}  -eq 64 || fatalerr "Peer's $i pubkey length must be 64, got ${#pubkey} in '$pubkey'"
   test ${#privkey} -eq 64 || fatalerr "Peer's $i privkey length must be 64, got ${#privkey} in '$privkey'"
   echo -n "$pubkey"  >iroha$i.pub
   echo -n "$privkey" >iroha$i.priv

   ## Localhost uses different ports and paths, different hosts (docker containers) uses same ports and paths
   if test_yes use_localhost ;then
      if var_is_set_not_empty host; then echowarn "On host without container peer's $1 hostname $hostname is overridden."; fi
      host=localhost
      postgres_host=${postgres_host:-localhost}
      block_store_path=/tmp/block_store_$i
      config_internal_port=$port #$((10000+i))
      config_torii_port=$((50050+i))
      config_metrics_port=$((7000+i))
      config_metrics="0.0.0.0:$config_metrics_port"
      rocksdb_path_="${rocksdb_path}_$i"
   else ## docker
      host=${host:=iroha$i}
      postgres_host=irpsql ## Must be same as in docker-compose.yaml
      block_store_path=/tmp/block_store
      if var_is_set_not_empty port; then echowarn "In container port '$port' for peer $i $host is overridden."; fi
      config_internal_port=10001
      config_torii_port=50051
      config_metrics_port=7001
      config_metrics="0.0.0.0:$config_metrics_port"
      rocksdb_path_="${rocksdb_path}"
   fi

   ## genesis.block : add each peer
   peers_out+="$host:$config_internal_port:$pubkey:$privkey,"
   JSON_peers+="{addPeer:{peer:{address:\"$host:$config_internal_port\",peerKey:\"$pubkey\"}}},"

   ## Generate config file for each peer
   # pgopt="$( cat iroha.base.config | jq -r .pg_opt |
   #    sed -E 's,dbname=[A-Za-z_0-9]+,dbname=$pgopt_dbname,g' )"
   cat $script_dir/iroha.base.config |
      jq ".block_store_path=\"$block_store_path\" |
          .torii_port=$config_torii_port |
          .internal_port=$config_internal_port |
          .metrics=\"$config_metrics\" |
          if \"rocksdb\" == \"$dbtype\"
          then .database={type:\"rocksdb\",path:\"$rocksdb_path_\"} | del(.pg_opt)
          else .pg_opt=\"dbname=iroha$i host=$postgres_host port=${postgres_port:=5432} user=postgres password=postgres\"
          end
         " \
      >iroha$i.config

   ## Generate docker-compose.yaml (for -docker)
   if test_no use_localhost ;then
      base_internal_port=${base_internal_port:-10000}
      base_torii_port=${base_torii_port:-50050};
      base_metrics_port=${base_metrics_port:-7000}
      yaml="
         x-workaround: &service_iroha_tech  ## See https://github.com/mikefarah/yq/issues/889#issuecomment-877728821
         services:
            iroha$i:
               <<: *service_iroha_tech
               container_name: iroha$i
               ports:
               #- $((base_internal_port+i)):$config_internal_port  ## expose to connect with iroha nodes outside of this docker network and host
               - $((base_torii_port+i)):$config_torii_port
               - $((base_metrics_port+i)):$config_metrics_port  ## Metrics
               volumes:
               $( [[ $dbtype = postgres ]] && echo "- block_store_$i:$block_store_path")
               $( [[ $dbtype = rocksdb ]] && echo "- iroha_rocksdb_$i:$rocksdb_path")
               - ./genesis.block:/opt/iroha_data/genesis.block
               - ./iroha$i.config:/opt/iroha_data/config.docker
               - ./iroha$i.priv:/opt/iroha_data/iroha.tech.priv
               - ./iroha$i.pub:/opt/iroha_data/iroha.tech.pub
         $( [[ $dbtype = rocksdb ]]  && echo "volumes: { iroha_rocksdb_$i: }" )
         $( [[ $dbtype = postgres ]] && echo "volumes: { block_store_$i: }" )
         " \
      yq e 'select(fileIndex == 0) * env(yaml) | del(.x-workaround) | .. style|=""' -i docker-compose.yaml

      metrics_ports+=' '$((base_metrics_port+i))
      torii_ports+=' '$((base_torii_port+i))
   else
      metrics_ports+=' '$config_metrics_port
      torii_ports+=' '$config_torii_port
   fi
done

echo "$peers_count nodes ready to run$(test_no use_localhost && echo ' 'inside containers || echo ' on localhost'):"
declare -i i=
echo "$peers_out" | while IFS=: read -d, host port pubkey privkey rest ;do
   echo "  $((++i)). $host:$port pub=$pubkey priv=$privkey"
done
if test_yes use_localhost ;then
   echo "According to config files"
   echo "  Metrics will listen at ports: "$metrics_ports
   echo "  Torii will listen at ports: "$torii_ports
else
   echo "According to docker-compose.yaml"
   echo "  Metrics exposed from docker to local ports: "$metrics_ports
   echo "  Torii exposed from docker to local ports: "$torii_ports
fi

## Remove trailing commas and generate genesis.block with command addPeers
JSON_peers="$(echo "$JSON_peers" | sed -E 's/,+$//')"
cat $script_dir/genesis.base.block |
   jq ".block_v1.payload.transactions[0].payload.reducedPayload.commands += [$JSON_peers]" \
   > genesis.block

if ! test_yes use_localhost ;then
   echo "To run iroha nodes in containers do:"
   echo "   env IROHA_IMAGE=hyperledger/iroha:latest docker-compose up --force-recreate"
else
   if test "$(realpath "$script_dir")" != "$(realpath .)"
   then cp "$script_dir"/run-irohas.sh ./ ;fi
   [[ "$dbtype" == postgres ]] &&
      echo "Assert PostgresDB is accessable with pg_opt '$(cat iroha1.config |jq -r .pg_opt | sed -Ee 's,([^ ]+),--\1,g' -e 's,--password.*,,' | xargs)'" #| xargs psql 'select version()'
   echo "To run iroha nodes on current host do:"
   echo "   env IROHAD=/path/to/irohad ./run-irohas.sh $peers_count"
fi
