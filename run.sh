#!/bin/bash

set -e

anvil &
sleep 1

bash ./dev-setup.sh

echo -------------
echo DEVLAND READY
echo -------------

wait
