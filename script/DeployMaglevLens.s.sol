// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {MaglevLens} from "../src/MaglevLens.sol";

contract DeployMaglevLens is Script {
    function run() public {
        // load wallet
        uint256 deployerKey = vm.envUint("WALLET_PRIVATE_KEY");
        address deployerAddress = vm.rememberKey(deployerKey);

        vm.startBroadcast(deployerAddress);

        address maglevLens = address(new MaglevLens());
        console.log("MAGLEVLENS = ", maglevLens);

        vm.stopBroadcast();
    }
}
