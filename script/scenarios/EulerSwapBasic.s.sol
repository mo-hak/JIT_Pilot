// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {DeployScenario} from "../DeployScenario.s.sol";

contract EulerSwapBasic is DeployScenario {
    function setup() internal virtual override {
        vm.startBroadcast(user0PK);

        giveLotsOfCash(user0);

        // Deposit some assets

        assetUSDC.approve(address(eUSDC), type(uint256).max);
        eUSDC.deposit(20000e6, user0);

        assetUSDT.approve(address(eUSDT), type(uint256).max);
        eUSDT.deposit(10000e6, user0);

        assetWETH.approve(address(eWETH), type(uint256).max);
        eWETH.deposit(10e18, user0);

        assetUSDZ.approve(address(eUSDZ), type(uint256).max);
        eUSDZ.deposit(10000e6, user0);

        // Some extra USDT to subaccount 1
        assetUSDT.approve(address(eUSDT), type(uint256).max);
        eUSDT.deposit(5000e6, getSubaccount(user0, 1));

        vm.stopBroadcast();
    }
}
