// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// System

import {Script, console} from "forge-std/Script.sol";

// Deploy base

import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";

import {EVault} from "evk/EVault/EVault.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";

import {Dispatch} from "evk/EVault/Dispatch.sol";

import {Initialize} from "evk/EVault/modules/Initialize.sol";
import {Token} from "evk/EVault/modules/Token.sol";
import {Vault} from "evk/EVault/modules/Vault.sol";
import {Borrowing} from "evk/EVault/modules/Borrowing.sol";
import {Liquidation} from "evk/EVault/modules/Liquidation.sol";
import {BalanceForwarder} from "evk/EVault/modules/BalanceForwarder.sol";
import {Governance} from "evk/EVault/modules/Governance.sol";
import {RiskManager} from "evk/EVault/modules/RiskManager.sol";

import {IEVault, IERC20} from "evk/EVault/IEVault.sol";
import {TypesLib} from "evk/EVault/shared/types/Types.sol";
import {Base} from "evk/EVault/shared/Base.sol";

import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";

import {TestERC20} from "evk-test/mocks/TestERC20.sol";
import {MockBalanceTracker} from "evk-test/mocks/MockBalanceTracker.sol";
import {MockPriceOracle} from "evk-test/mocks/MockPriceOracle.sol";
import {IRMTestDefault} from "evk-test/mocks/IRMTestDefault.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";
import {SequenceRegistry} from "evk/SequenceRegistry/SequenceRegistry.sol";

// Euler swap

import {TestERC20} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IEulerSwap, IEVC, EulerSwap} from "euler-swap/EulerSwap.sol";
import {EulerSwapFactory} from "euler-swap/EulerSwapFactory.sol";
import {EulerSwapPeriphery} from "euler-swap/EulerSwapPeriphery.sol";
import {PoolManagerDeployer} from "euler-swap/../test/utils/PoolManagerDeployer.sol";

// Maglev stuff

import {MaglevLens} from "src/MaglevLens.sol";


struct Asset {
    string symbol;
    address asset;
    address vault;
    string price;
    uint256 priceNum;
}

contract DeployDev is Script {
    //////// Users

    uint256 user0PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 user1PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 user2PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    uint256 user3PK = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;

    address user0 = vm.addr(user0PK);
    address user1 = vm.addr(user1PK);
    address user2 = vm.addr(user2PK);
    address user3 = vm.addr(user3PK);

    //////// Main system

    EthereumVaultConnector public evc;
    address admin;
    address feeReceiver;
    address protocolFeeReceiver;
    ProtocolConfig protocolConfig;
    address balanceTracker;
    MockPriceOracle oracle;
    address unitOfAccount;
    address permit2;
    address sequenceRegistry;
    GenericFactory public factory;

    Base.Integrations integrations;
    Dispatch.DeployedModules modules;

    address initializeModule;
    address tokenModule;
    address vaultModule;
    address borrowingModule;
    address liquidationModule;
    address riskManagerModule;
    address balanceForwarderModule;
    address governanceModule;

    //////// Tokens

    Asset[] assets;

    //////// EulerSwap

    address poolManager;
    address eulerSwapImpl;
    EulerSwapFactory eulerSwapFactory;
    EulerSwapPeriphery eulerSwapPeriphery;

    //////// Maglev

    MaglevLens maglevLens;

    function run() public {
        vm.startBroadcast(user3PK);

        deployEulerSystem();
        deployAssets();
        deployEulerSwap();
        deployMaglevLens();

        vm.stopBroadcast();

        setupUsers();
    }

    function deployEulerSystem() internal {
        admin = makeAddr("admin");
        feeReceiver = makeAddr("feeReceiver");
        protocolFeeReceiver = makeAddr("protocolFeeReceiver");
        factory = new GenericFactory(user3);

        evc = new EthereumVaultConnector();
        protocolConfig = new ProtocolConfig(admin, protocolFeeReceiver);
        balanceTracker = address(new MockBalanceTracker());
        oracle = new MockPriceOracle();
        unitOfAccount = address(1);
        permit2 = address(0);
        sequenceRegistry = address(new SequenceRegistry());
        integrations =
            Base.Integrations(address(evc), address(protocolConfig), sequenceRegistry, balanceTracker, permit2);

        initializeModule = address(new Initialize(integrations));
        tokenModule = address(new Token(integrations));
        vaultModule = address(new Vault(integrations));
        borrowingModule = address(new Borrowing(integrations));
        liquidationModule = address(new Liquidation(integrations));
        riskManagerModule = address(new RiskManager(integrations));
        balanceForwarderModule = address(new BalanceForwarder(integrations));
        governanceModule = address(new Governance(integrations));

        modules = Dispatch.DeployedModules({
            initialize: initializeModule,
            token: tokenModule,
            vault: vaultModule,
            borrowing: borrowingModule,
            liquidation: liquidationModule,
            riskManager: riskManagerModule,
            balanceForwarder: balanceForwarderModule,
            governance: governanceModule
        });

        address evaultImpl = address(new EVault(integrations, modules));

        factory.setImplementation(evaultImpl);

        string memory result = vm.serializeAddress("coreAddresses", "evc", address(evc));
        result = vm.serializeAddress("coreAddresses", "eVaultFactory", address(factory));
        vm.writeJson(result, "./dev-ctx/addresses/31337/CoreAddresses.json");
    }

    function genAsset(string memory symbol, uint8 decimals, string memory price, uint256 priceNum) internal returns (Asset memory a) {
        a.symbol = symbol;
        a.asset = address(new TestERC20(string(abi.encodePacked(symbol, " Token")), symbol, decimals, false));
        a.vault = factory.createProxy(address(0), true, abi.encodePacked(a.asset, address(oracle), unitOfAccount));
        a.price = price;
        a.priceNum = priceNum;
        IEVault(a.vault).setHookConfig(address(0), 0);
        IEVault(a.vault).setInterestRateModel(address(new IRMTestDefault()));
        IEVault(a.vault).setMaxLiquidationDiscount(0.2e4);
        IEVault(a.vault).setFeeReceiver(feeReceiver);
    }

    function deployAssets() internal {
        assets.push(genAsset("WETH", 18, "2865", 2865e18));
        assets.push(genAsset("wstETH", 18, "3055", 3055e18));
        assets.push(genAsset("USDC", 6, "1.000142", 1e18 * 1e12));
        assets.push(genAsset("USDT", 6, "0.999218", 1e18 * 1e12));
        assets.push(genAsset("DAI", 18, "1.00123", 1e18));
        assets.push(genAsset("USDZ", 6, "1.00081", 1e18 * 1e12));

        for (uint256 i; i < assets.length; ++i) {
            oracle.setPrice(assets[i].vault, unitOfAccount, assets[i].priceNum);

            for (uint256 j; j < assets.length; ++j) {
                if (i == j) continue;
                IEVault(assets[i].vault).setLTV(assets[j].vault, 0.92e4, 0.94e4, 0);
            }
        }

        IEVault(assets[0].vault).setLTV(assets[1].vault, 0.5e4, 0.52e4, 0); // lower wstETH/WETH LTV for testing
        IEVault(assets[1].vault).setLTV(assets[0].vault, 0.91e4, 0.93e4, 0); // change WETH/wstETH LTV for testing
        IEVault(assets[1].vault).setLTV(assets[2].vault, 0.8e4, 0.82e4, 0); // change USDC/wstETH LTV for testing

        IEVault(assets[0].vault).setLTV(assets[2].vault, 0.65e4, 0.67e4, 0); // change USDC/WETH LTV for testing
        IEVault(assets[0].vault).setLTV(assets[3].vault, 0.85e4, 0.87e4, 0); // change USDT/WETH LTV for testing

        address[] memory vaults = new address[](assets.length);
        for (uint256 i; i < assets.length; ++i) {
            vaults[i] = assets[i].vault;
        }

        {
            string memory result = vm.serializeAddress("products", "vaults", vaults);
            string memory obj = vm.serializeString("products2", "testing-product", result);
            vm.writeJson(obj, "./dev-ctx/labels/31337/products.json");
        }

        {
            string memory pricesFile = "./dev-ctx/priceapi/31337/prices.json";
            vm.writeLine(pricesFile, "{");

            for (uint256 i; i < assets.length; ++i) {
                string memory line = string(abi.encodePacked("\"", vm.toString(assets[i].asset), "\": {\"price\":", assets[i].price, "}", (i == assets.length - 1 ? "" : ",") ));
                vm.writeLine(pricesFile, line);
            }

            vm.writeLine(pricesFile, "}");
        }
    }

    function deployEulerSwap() internal {
        poolManager = address(PoolManagerDeployer.deploy(address(0)));
        eulerSwapImpl = address(new EulerSwap(address(evc), poolManager));
        eulerSwapFactory = new EulerSwapFactory(address(evc), address(factory), eulerSwapImpl, address(0), address(0));
        eulerSwapPeriphery = new EulerSwapPeriphery();

        string memory result = vm.serializeAddress("eulerSwap", "eulerSwapFactory", address(eulerSwapFactory));
        result = vm.serializeAddress("eulerSwap", "eulerSwapPeriphery", address(eulerSwapPeriphery));
        vm.writeJson(result, "./dev-ctx/addresses/31337/EulerSwapAddresses.json");
    }

    function deployMaglevLens() internal {
        maglevLens = new MaglevLens();

        string memory result = vm.serializeAddress("maglev", "maglevLens", address(maglevLens));
        vm.writeJson(result, "./dev-ctx/addresses/31337/MaglevAddresses.json");
    }

    function getSubaccount(address user, uint8 account) internal pure returns (address) {
        return address(uint160(user) ^ account);
    }

    function setupUsers() internal {
        IEVault eWETH = IEVault(assets[0].vault);
        TestERC20 assetWETH = TestERC20(eWETH.asset());

        IEVault ewstETH = IEVault(assets[1].vault);
        TestERC20 assetwstETH = TestERC20(ewstETH.asset());

        IEVault eUSDC = IEVault(assets[2].vault);
        TestERC20 assetUSDC = TestERC20(eUSDC.asset());

        IEVault eUSDT = IEVault(assets[3].vault);
        TestERC20 assetUSDT = TestERC20(eUSDT.asset());

        IEVault eDAI = IEVault(assets[4].vault);
        TestERC20 assetDAI = TestERC20(eDAI.asset());

        IEVault eUSDZ = IEVault(assets[5].vault);
        TestERC20 assetUSDZ = TestERC20(eUSDZ.asset());

        // user2 is passive depositor
        vm.startBroadcast(user2PK);

        assetUSDC.mint(user2, 1000000e6);
        assetUSDT.mint(user2, 1000000e6);
        assetWETH.mint(user2, 100000e18);
        assetwstETH.mint(user2, 100000e18);
        assetDAI.mint(user2, 1000000e18);
        assetUSDZ.mint(user2, 1000000e6);

        assetUSDC.approve(address(eUSDC), type(uint256).max);
        assetUSDT.approve(address(eUSDT), type(uint256).max);
        assetWETH.approve(address(eWETH), type(uint256).max);
        assetwstETH.approve(address(ewstETH), type(uint256).max);
        assetDAI.approve(address(eDAI), type(uint256).max);
        assetUSDZ.approve(address(eUSDZ), type(uint256).max);

        eUSDC.deposit(1000000e6, user2);
        eUSDT.deposit(1000000e6, user2);
        eWETH.deposit(100000e18, user2);
        ewstETH.deposit(100000e18, user2);
        eDAI.deposit(1000000e18, user2);
        eUSDZ.deposit(1000000e6, user2);

        vm.stopBroadcast();

        // user0 is going to setup a position
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


/*
        // Deposit some USDT shares to user0 subaccount 1
        assetUSDT.mint(user2, 10000e6);
        assetUSDT.approve(address(eUSDT), type(uint256).max);
        eUSDT.deposit(10000e6, getSubaccount(user0, 1));

        //assetUSDZ.mint(user0, 10000e6);
        //assetUSDZ.approve(address(eUSDZ), type(uint256).max);
        //eUSDZ.deposit(10000e6, getSubaccount(user0, 1));
        */

        // Give a bunch of extra spending cash

        assetUSDC.mint(user0, 1000000e6);
        assetUSDT.mint(user0, 1000000e6);
        assetWETH.mint(user0, 1000e18);
        assetwstETH.mint(user0, 1000e18);
        assetDAI.mint(user0, 1000000e18);

        //assetUSDC.approve(address(eulerSwapPeriphery), type(uint256).max);
        //assetUSDT.approve(address(eulerSwapPeriphery), type(uint256).max);
        //assetWETH.approve(address(eulerSwapPeriphery), type(uint256).max);
        //assetDAI.approve(address(eulerSwapPeriphery), type(uint256).max);

        vm.stopBroadcast();
    }
}
