#!/bin/bash

set -e

SCENARIO=${1:-EulerSwapBasic}


function cleanup {
    pkill -P $$
}

trap cleanup EXIT


anvil --code-size-limit 100000 &
sleep 1


bash ./deploy-scenario.sh "$SCENARIO"


echo -------------------------------
echo DEVLAND READY
echo SCENARIO = $SCENARIO
echo -------------------------------

wait
