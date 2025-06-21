// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {DeployScenario} from "../DeployScenario.s.sol";

contract EulerSwapExternalDebt is DeployScenario {
    function setup() internal virtual override {
        giveLotsOfCash(user0);

        // user0 supplies USDC and USDT, and borrows WETH

        vm.startBroadcast(user0PK);

        evc.enableCollateral(user0, address(eUSDC));
        evc.enableCollateral(user0, address(eUSDT));

        assetUSDC.mint(user0, 10000e6);
        assetUSDC.approve(address(eUSDC), type(uint256).max);
        eUSDC.deposit(10000e6, user0);

        assetUSDT.mint(user0, 30000e6);
        assetUSDT.approve(address(eUSDT), type(uint256).max);
        eUSDT.deposit(30000e6, user0);

        evc.enableController(user0, address(eWETH));
        eWETH.borrow(10e18, user0);

        vm.stopBroadcast();
    }
}
