#!/bin/bash

set -e

rm -rf dev-ctx/
mkdir -p dev-ctx/{addresses,labels,priceapi}/31337

forge script --rpc-url http://127.0.0.1:8545 script/DeployDev.sol --broadcast
cast rpc evm_increaseTime 86400
cast rpc evm_mine

node chains.js
