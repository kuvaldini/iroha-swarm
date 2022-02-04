#/usr/bin/env bash -e

SD=$(dirname ${BASH_SOURCE[0]})

sed -i -Ee 's,^(readonly VERSION=).*,\1'$($SD/git-rev-label.sh '$refname-c$count-g$short')',' \
        -e 's,^(readonly VERSION_NPM=[0-9]+\.).*,\1'$($SD/git-rev-label.sh '$count')'.0,' \
    ./iroha-swarm.sh

#git add ./iroha-swarm.sh
