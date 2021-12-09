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

function --help {
   echo -n \
'Produce configuration files to run Hyperledger/Iroha network
of multiple instances.

USAGE:
   iroha-swarm.sh [--help|-h|-?]
   iroha-swarm.sh [--version|-V]
   iroha-swarm.sh --peers=
   iroha-swarm.sh [peers_count]   default:4

OPTIONS:
   --peers_count=N
   --peers=host1:port1:pubkey1:privkey1,host2:port2:pubkey2:privkey1

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
      --peers=*)
         set_with_warn peers "${1##--peers=}" ;;
      --base_torii_port=*)
         set_with_warn_from_arg "$1" ;;
      --postgres_host=*|--postgres_port=*|--pg_opt=*)
         set_with_warn_from_arg "$1" ;;
      -l|--local|--localhost|--no-docker|--without-docker)
         use_localhost=yes ;;
      -x|--trace|--xtrace)
         # PS4=$'\e[32m+ '
         set -x ;;
      +x|--no-trace|--no-xtrace)
         set +x ;;
      --debug|-D)  ## Allow echodbg messages, also works if DEBUG is set in environment
         DEBUG=y ;;
      --no-debug)  ## Allow echodbg messages, also works if DEBUG is set in environment
         unset DEBUG ;;
      --peers_count=*)
         if var_is_set_not_empty peers
         then fatalerr "--peers cannot be used with --peers_count"
         else set_with_warn_from_arg "$1"
         fi
         ;;
      -*|--*)
         fatalerr "!!! Unknown option '$1'" ;;
      *)
         if var_is_set_not_empty peers
         then fatalerr "--peers cannot be used with --peers_count"
         else set_with_warn peers_count "$1" 
         fi
         ;;
   esac
   shift
done

{ var_is_unset_or_empty peers_count && var_is_unset_or_empty peers; } || 
{ var_is_set_not_empty peers_count && var_is_set_not_empty peers; } && 
   fatalerr "Only one and at least one of --peers or --peers_count must be set."

if test_no use_localhost ;then
   var_is_set_not_empty postgres_host && echowarn "postgres_host ignored for iroha-swarm in docker"
   var_is_set_not_empty postgres_port && echowarn "postgres_port ignored for iroha-swarm in docker"
   var_is_set_not_empty pg_opt && echowarn "pg_opt ignored for iroha-swarm in docker"
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
# peers_count=${peers_count:=${#PUB_KEYS[@]}}
var_is_unset_or_empty peers && {
   test $peers_count -le ${#PUB_KEYS[@]}
   for (( i=1; i<=$peers_count; ++i )); do 
      if test_yes use_localhost ;then
         host= #localhost
         port=$((10000+i))
      else
         host=${host:=iroha$i}
         port= #10001
      fi
      peers+=$host:$port:${PUB_KEYS[$((i-1))]}:${PRIV_KEYS[$((i-1))]},
   done; 
}
# readonly peers_count=${peers_count:=${#PUB_KEYS[@]}}

## Prepare docker-compose file for future editing
if ! test_yes use_localhost ;then
   cp $script_dir/docker-compose.base.yml docker-compose.yaml
fi

## Parse peers and fill files
peers_out=
JSON_peers=
declare -i i=1
peers="$(echo "$peers" | sed -E 's/,+$//')",

echo "$peers" |
 while IFS=: read -d, host port pubkey privkey rest ;do
   [[ -n "$rest" ]] && fatalerr "Unexpected rest '$rest'"
   
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
   else ## docker
      host=${host:=iroha$i}
      postgres_host=irpsql ## Must be same as in docker-compose.yaml
      block_store_path=/tmp/block_store
      if var_is_set_not_empty port; then echowarn "In container port '$port' for peer $i $host is overridden."; fi
      config_internal_port=10001
      config_torii_port=50051
      config_metrics_port=7001
      config_metrics="0.0.0.0:$config_metrics_port"
   fi

   ## genesis.block : add each peer
   peers_out+="$host:$config_internal_port:$pubkey:$privkey,"
   JSON_peers+="{addPeer:{peer:{address:\"$host:$config_internal_port\",peerKey:\"$pubkey\"}}},"

   ## Generate config file for each peer
   # pgopt="$( cat iroha.base.config | jq -r .pg_opt | 
   #    sed -E 's,dbname=[A-Za-z_0-9]+,dbname=$pgopt_dbname,g' )"
   cat $script_dir/iroha.base.config | 
      jq ".pg_opt=\"dbname=iroha$i host=$postgres_host port=${postgres_port:=5432} user=postgres password=postgres\" |
          .block_store_path=\"$block_store_path\" | 
          .torii_port=$config_torii_port | 
          .internal_port=$config_internal_port | 
          .metrics=\"$config_metrics\" " \
      >iroha$i.config
   
   ## Generate docker-compose.yaml (for not --local)
   if test_no use_localhost ;then
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
               - block_strore_$i:$block_store_path
               - ./genesis.block:/opt/iroha_data/genesis.block
               - ./iroha$i.config:/opt/iroha_data/config.docker
               - ./iroha$i.priv:/opt/iroha_data/iroha.tech.priv
               - ./iroha$i.pub:/opt/iroha_data/iroha.tech.pub
               - iroha-dev:/opt/iroha" \
      yq e 'select(fileIndex == 0) * env(yaml) | del(.x-workaround)' -i docker-compose.yaml
   fi

   ((++i))
done
peers_count=$((i-1))

echo "$peers_count nodes ready to run$(test_no use_localhost && echo ' 'inside containers):"
declare -i i=
echo "$peers_out" | while IFS=: read -d, host port pubkey privkey rest ;do
   echo "  $((++i)). $host:$port pub=$pubkey priv=$privkey"
done

## Remove trailing commas and generate genesis.block with command addPeers
JSON_peers="$(echo "$JSON_peers" | sed -E 's/,+$//')"
cat $script_dir/genesis.base.block | 
   jq ".block_v1.payload.transactions[0].payload.reducedPayload.commands += [$JSON_peers]" \
   > genesis.block

if ! test_yes use_localhost ;then
   echo "Next do:"
   echo "   env IROHA_IMAGE=hyperledger/iroha:latest docker-compose up --force-recreate"
else
   if test "$(realpath "$script_dir")" != "$(realpath .)"
   then cp "$script_dir"/run-irohas.sh ./ ;fi
   echo "Assert PostgresDB is available to connect via pg_opt. Then:"  ##TRY cat iroha1.config |jq -r .pg_opt | sed -Ee 's,([^ ]+),--\1,g' -e 's,--password.*,,' | xargs psql 'select version()'
   echo "   env IROHAD=/path/to/irohad ./run-irohas.sh $peers_count"
fi
