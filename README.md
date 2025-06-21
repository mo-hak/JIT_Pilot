# Euler Devland

Devland is a framework for running a simple testing blockchain (anvil) and installing a basic instance of the Euler contracts for development and testing purposes.

* Fast and deterministic: The entire environment can be created and installed in a second or two. This lets you setup testing/dev scenarios and instantly reset them to the starting conditions, which is helpful for development.
* Self-contained scenarios can be created to reproduce a starting state, and to send the state to other devs, who can get started instantly.
* Lightweight: It does not use forge-style nested submodules. Instead, each project is checked out exactly once in a `libflat` directory, and then remappings are used to map depenencies for each project. This means that each repo is only checked out once, saving time and diskspace. However, it also means that only a single version of a dependency can be installed, globally.

## Usage

### Installation

First [install foundry](https://getfoundry.sh/) then run:

    ./install.sh

### Run devland

    ./devland.sh

If all goes well, your RPC will be available on the standard `http://127.0.0.1:8545` endpoint.

### Private keys

The default is just to use the standard anvil mnemonic. For example this is user 0:

* Private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
* Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

Import the above private key into metamask, and then change network to Foundry (chain id 31337).


## Scenarios

Scenarios are Solidity scripts that inherit from the `DeployScenario` contract, and live in the directory `script/scenarios/`.

To build your own scenario, copy one of the existing scenario files, edit it to meet your requirements, and then provide the scenario name as an argument to the `devland.sh` script. For example:

    ./devland.sh MyCustomScenario


## Extras

Devland also sets up some configuration files for the dev network. They are in the same format as production for ease of integration:

* `dev-ctx/EulerChains.json` - A chain manifest in the same format as [EulerChains.json](https://github.com/euler-xyz/euler-interfaces/blob/master/EulerChains.json)
* `dev-ctx/labels/31337/products.json` - A `products.json` in the same format as [euler-labels](https://github.com/euler-xyz/euler-labels/blob/master/1/products.json)
* `dev-ctx/addresses/31337/CoreAddresses.json` - Address files in the same format as [euler-interfaces](https://github.com/euler-xyz/euler-interfaces/blob/master/addresses/1/CoreAddresses.json)
* `dev-ctx/priceapi/31337/prices.json` - A sample output from the [prices API](https://app.euler.finance/api/v1/price?chainId=1).



## Deploy MaglevLens:

For now, this repo also contains some lens code, until it can find a better home. To deploy, put a `WALLET_PRIVATE_KEY` into `.env` and then run:

    forge script ./script/DeployMaglevLens.s.sol --rpc-url $RPC_URL --broadcast --slow
