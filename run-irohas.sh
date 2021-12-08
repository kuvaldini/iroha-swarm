#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

## Useful to use when iroha-swarm --without-docker

##TODO
# initdb /path/to/db -Upostgres
# postgres -D/path/to/db &


IROHAD=~/devel/iroha/build/bin/irohad

COLORS=(0 39 126 184 214 141)
NOCOLOR="$(tput sgr0)"
colorful_prefix(){
    # while read; do 
    #     echo $'\e[38;5;'${COLORS[$i]}m"node$i | $NOCOLOR""$REPLY"
    # done
    PREFIX=$'\e[38;5;'${COLORS[$i]}m"node$i | $NOCOLOR"
    sed s,^,"$PREFIX",
    # awk '{print "'"$PREFIX "'" $0}'
}


PIDs=()
N=${1:-4}
for (( i=1; i<=N; ++i )) ;do
    $IROHAD --config iroha$i.config --genesis_block genesis.block --keypair_name iroha$i \ #--overwrite_ledger --drop_state \
        &>iroha$i.log  & #1> >(colorful_prefix)  2> >(colorful_prefix) & 
    PIDs+=($!)
    tail -f iroha$i.log | colorful_prefix &
    sleep 0.1
done

wait
# kill ${PIDs[@]}
# sleep 10
# kill -9 ${PIDs[@]}

# while kill -0 ${PIDs[@]} ;do
#     sleep 2;
#     echo >&2 "----------- Waiting for PIDs ${PIDs[@]}"
# done
