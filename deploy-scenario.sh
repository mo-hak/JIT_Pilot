#!/bin/bash

set -e

SCENARIO=$1

rm -rf dev-ctx/
mkdir -p dev-ctx/{addresses,labels,priceapi}/31337

forge script --rpc-url http://127.0.0.1:8545 "script/scenarios/$SCENARIO.s.sol" --broadcast --code-size-limit 100000
cast rpc evm_increaseTime 86400
cast rpc evm_mine

node chains.js
