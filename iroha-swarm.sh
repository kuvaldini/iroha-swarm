#!/usr/bin/env bash
set -eEuo pipefail
shopt -s inherit_errexit
shopt -s lastpipe
shopt -s expand_aliases

readonly script_dir=$(dirname $(realpath "$0"))

VERSION=UNKNOWN
VERSION_NPM=0.0.0

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

function --help {
   echo -n \
'ToDo

USAGE:
   iroha-swarm.sh [--help|-h|-?]
   iroha-swarm.sh [--version|-V]
   iroha-swarm.sh --peers=
   iroha-swarm.sh [peers_count]   default:4

OPTIONS:
   --peers_count=N
   --peers=host1:port1:pubkey1,host2:port2:pubkey2

'
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
   var_is_set $varname  && echowarn "!!! $varname already set to '${!varname}'. Overriding"
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

while [[ $# > 0 ]] ;do
   case $1 in
      --peers=*)
         set_with_warn peers "${1##--peers=}" ;;
      --base_torii_port=*)
         set_with_warn_from_arg "$1" ;;
      -l|--local|--localhost|--no-docker|--without-docker)
         localhost=yes ;;
      -x|--trace|--xtrace)
         # PS4=$'\e[32m+ '
         set -x;
         ;;
      +x|--no-trace|--no-xtrace)
         set +x;
         ;;
      --debug|-D)  ## Allow echodbg messages, also works if DEBUG is set in environment
         DEBUG=y
         ;;
      --no-debug)  ## Allow echodbg messages, also works if DEBUG is set in environment
         unset DEBUG
         ;;
      -*|--*) fatalerr "!!! Unknown option '$1'" ;;
      *)
         set_with_warn peers_count "$1"
         ;;
   esac
   shift
done

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
readonly peers_count=${peers_count:=4}
test $peers_count -le ${#PUB_KEYS[@]}

COMPOSE_YML=
JSON_peers=
json_edit(){
   json="$(echo "$JSON_peers" | jq "$@")" #|| echo "$json")"
}
var_is_unset_or_empty peers && for (( i=1; i<$peers_count; ++i )); do 
   peers+=,
done

if ! test_yes localhost ;then
   cp $script_dir/docker-compose.base.yml docker-compose.yaml
fi

## Parse peers and fill files
comma=
peers_out=
declare -i i=1
echo "${peers:=}," | while IFS=: read -d, host port pubkey rest ;do
   [[ -n "$rest" ]] && fatalerr "Unexpected rest '$rest'"
   ## Localhost uses different ports and paths, different hosts (docker containers) uses same ports and paths
   if test_yes localhost ;then
      host=localhost
      postgres_host=localhost
      block_store_path=/tmp/block_store_$i
      config_torii_port=$((50050+i))
      config_internal_port=$((10000+i))
      config_metrics_port=7001
      config_metrics="0.0.0.0:$config_metrics_port"
   else
      host=${host:=iroha$i}
      postgres_host=irpsql
      block_store_path=/tmp/block_store
      config_torii_port=50051
      config_internal_port=10001
      config_metrics_port=7001
      config_metrics="0.0.0.0:$config_metrics_port"
      host_internal_port=${base_internal_port:-10000}
      host_torii_port=${base_torii_port:-50050}; 
      host_metrics_port=${base_metrics_port:-6500}
   fi
   
   if ! printf %d "$config_internal_port" &>/dev/null && 
      ((config_internal_port>0 && config_internal_port<=65535))
   then fatalerr "Peer's $i port must be non-zero 16bit number, got '$config_internal_port'"
   fi
   
   var_is_unset_or_empty pubkey && {
      #fatalerr "Key must be set not empty"
      pubkey=${PUB_KEYS[$((i-1))]}
      #echo "Note: Peer's $i pubkey was not set, using from default pool '$pubkey'"
      echo -n "$pubkey" >iroha$i.pub
      echo -n "${PRIV_KEYS[$((i-1))]}" >iroha$i.priv
   }
   test ${#pubkey} -eq 64 || fatalerr "Peer's $i pubkey length must be 64, got ${#pubkey} in '$pubkey'"

   peers_out+="$host:$config_internal_port $pubkey,"
   # echo "$i: $host:$config_internal_port $pubkey"
   JSON_peers+="$comma {addPeer:{peer:{address:\"$host:$config_internal_port\",peerKey:\"$pubkey\"}}}"
   comma=,

   # pgopt="$( cat iroha.base.config | jq -r .pg_opt | 
   #    sed -E 's,dbname=[A-Za-z_0-9]+,dbname=$pgopt_dbname,g' )"
   cat $script_dir/iroha.base.config | 
      jq ".pg_opt=\"dbname=iroha$i host=$postgres_host port=5432 user=postgres password=postgres\" |
          .block_store_path=\"$block_store_path\" | 
          .torii_port=$config_torii_port | 
          .internal_port=$config_internal_port | 
          .metrics=\"$config_metrics\" " \
      >iroha$i.config
   
   if ! test_yes localhost ;then
      base_internal_port=${base_internal_port:-10000}
      base_torii_port=${base_torii_port:-50050}; 
      base_metrics_port=${base_metrics_port:-6500}
      yaml="
         x-workaround: &service_iroha_tech  ## See https://github.com/mikefarah/yq/issues/889#issuecomment-877728821
         services:
            iroha$i:
               <<: *service_iroha_tech
               container_name: iroha$i
               ports:
               #- $((base_internal_port+i)):$config_internal_port
               - $((base_torii_port+i)):$config_torii_port
               - $((base_metrics_port+i)):$config_metrics_port  ## Metrics
               volumes:
               - block_strore_$i:/tmp/block_store
               - ./genesis.block:/opt/iroha_data/genesis.block
               - ./iroha$i.config:/opt/iroha_data/config.docker
               - ./iroha$i.priv:/opt/iroha_data/iroha.tech.priv
               - ./iroha$i.pub:/opt/iroha_data/iroha.tech.pub
               - iroha-dev:/opt/iroha" \
      yq e 'select(fileIndex == 0) * env(yaml) | del(.x-workaround)' -i docker-compose.yaml
   fi

   ((++i))
done

echo "$peers_count nodes ready to run:"
declare -i i=
echo "$peers_out" | while IFS=: read -d, host port pubkey rest ;do
   echo "  $((++i)). $host:$port $pubkey"
   # JSON_peers+="$comma {addPeer:{peer:{address:\"$host:$config_internal_port\",peerKey:\"$pubkey\"}}}"
   # comma=,
done
cat $script_dir/genesis.base.block | 
   jq ".block_v1.payload.transactions[0].payload.reducedPayload.commands += [$JSON_peers]" \
   > genesis.block

echo "Next do:"
if ! test_yes localhost ;then
   echo "   env IROHA_IMAGE=hyperledger/iroha:latest docker-compose up --force-recreate"
else
   cp "$script_dir"/run-irohas.sh ./
   echo "   env IROHAD=/path/to/irohad ./run-irohas.sh"
fi
