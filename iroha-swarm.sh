#!/usr/bin/env bash
set -eEuo pipefail
shopt -s inherit_errexit
shopt -s lastpipe
shopt -s expand_aliases

readonly script_dir=$(dirname $(realpath "$0"))

VERSION=UNKNOWN
VERSION_NPM=0.0.0

function echomsg      { echo $'\e[1;37m'"$@"$'\e[0m'; }
# alias echoinfo=echomsg
function echonote { >&2 echo $'\e[1;37m'NOTE$'\e[0m' "$@"; }
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
   iroha-swarm.sh  default 4 noodes
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
   varname=$1
   shift
   var_is_set $varname  && echowarn "!!! $varname already set to '${!varname}'. Overriding"
   declare -g $varname="$@"
}

while [[ $# > 0 ]] ;do
   case $1 in
      --peers=*)
         set_with_warn peers "${1##--peers=}" ;;
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

cp $script_dir/docker-compose.base.yml docker-compose.yaml

## Parse peers and fill files
comma=
declare -i i=1
echo "${peers:=}," | while IFS=: read -d, host port pubkey rest ;do
   [[ -n "$rest" ]] && fatalerr "Unexpected rest '$rest'"
   host=${host:=iroha$i}
   port=${port:=10001} #$((10000+$i))}
   printf %d "$port" &>/dev/null && ((port>0 && port<=65535)) || fatalerr "Peer's $i port must be non-zero 16bit number, got '$port'"
   var_is_unset_or_empty pubkey && {
      #fatalerr "Key must be set not empty"
      pubkey=${PUB_KEYS[$((i-1))]}
      echonote "Peer's $i pubkey was not set, using from default pool '$pubkey'"
      echo "$pubkey" >iroha$i.pub
      echo "${PRIV_KEYS[$((i-1))]}" >iroha$i.priv
   } || {
      test ${#pubkey} -eq 64 || fatalerr "Peer's $i pubkey length must be 64, got ${#pubkey} in '$pubkey'"
   }
   echo "$host $port $pubkey"
   JSON_peers+="$comma {addPeer:{peer:{address:\"$host:$port\",peerKey:\"$pubkey\"}}}"
   comma=,

   cat $script_dir/iroha.base.config | 
      jq ".pg_opt=\"dbname=iroha$i host=irpsql port=5432 user=postgres password=postgres\"" \
      >iroha$i.config
   
   yaml="
services:
   iroha$i:
      <<: service_iroha_tech
      container_name: iroha$i
      ports:
      - $((10000+$i)):10001
      - $((50050+$i)):50051
      - $((5550+$i)):5551  ## Metrics
      volumes:
      - block_strore_$i:/tmp/block_store
      - ./genesis.block:/opt/iroha_data/genesis.block
      - ./iroha$i.config:/opt/iroha_data/config.docker
      - ./iroha$i.priv:/opt/iroha_data/iroha.tech.priv
      - ./iroha$i.pub:/opt/iroha_data/iroha.tech.pub
      - iroha-dev:/opt/iroha" \
   yq e 'select(fileIndex == 0) * env(yaml)' -i docker-compose.yaml

   ## replace anchors because yq Error: yaml: unknown anchor 'service_iroha_tech' referenced
   sed -i 's,<<: service_iroha_tech,<<: *service_iroha_tech,' docker-compose.yaml

   echo ------------------ $i

   ((++i))
done

cat $script_dir/genesis.base.block | 
   jq ".block_v1.payload.transactions[0].payload.reducedPayload.commands += [$JSON_peers]" \
   > genesis.block
