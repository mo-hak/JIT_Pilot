#!/bin/bash

set -e

anvil --code-size-limit 100000 &
sleep 1

bash ./dev-setup.sh

echo -------------
echo DEVLAND READY
echo -------------

wait
