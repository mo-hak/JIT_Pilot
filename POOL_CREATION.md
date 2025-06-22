# EulerSwap Pool Creation Guide

This guide explains how to successfully create EulerSwap pools with Uniswap v4 integration.

## Quick Start

### 1. Deploy Pool with Auto Salt Mining

```bash
./deploy-scenario.sh EulerSwapPoolCreation
```

This scenario automatically:
- Deploys USDC and USDT vaults with liquidity
- Mines a valid salt using HookMiner
- Creates the pool successfully

### 2. Mine Salt for Custom Pool

```bash
forge script script/MineSaltForPool.s.sol --rpc-url http://localhost:8545
```

Configure with environment variables:
- `VAULT0`: First vault address
- `VAULT1`: Second vault address  
- `EULER_ACCOUNT`: Account that will own the pool
- `FACTORY`: EulerSwapFactory address
- `IMPL`: EulerSwap implementation address

## Background

EulerSwap pools act as hooks for Uniswap v4. Uniswap v4 requires hook addresses to have specific permission bits encoded in their address. This presents a challenge because EulerSwap uses MetaProxy deployment, which means the actual pool address must have the correct permission bits.

## Solution: HookMiner

The solution is to use the `HookMiner` utility from the EulerSwap test suite to find a salt that produces a valid hook address.

## How It Works

1. **Define Pool Parameters**: Set up your pool configuration (vaults, reserves, fees, etc.)

2. **Calculate Required Flags**: EulerSwap pools need these permission flags:
   - `BEFORE_INITIALIZE_FLAG` 
   - `BEFORE_SWAP_FLAG`
   - `BEFORE_SWAP_RETURNS_DELTA_FLAG`
   - `BEFORE_DONATE_FLAG`
   - `BEFORE_ADD_LIQUIDITY_FLAG`

3. **Mine Salt**: Use HookMiner to find a salt that produces an address with the correct permission bits:
   ```solidity
   bytes memory creationCode = MetaProxyDeployer.creationCodeMetaProxy(eulerSwapImpl, abi.encode(poolParams));
   (address hookAddress, bytes32 salt) = HookMiner.find(address(eulerSwapFactory), flags, creationCode);
   ```

4. **Deploy Pool**: Use the mined salt in your deployment through EVC batch

## Key Code Example

```solidity
// Mine salt
uint160 flags = uint160(
    Hooks.BEFORE_INITIALIZE_FLAG | 
    Hooks.BEFORE_SWAP_FLAG | 
    Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG |
    Hooks.BEFORE_DONATE_FLAG | 
    Hooks.BEFORE_ADD_LIQUIDITY_FLAG
);

bytes memory creationCode = MetaProxyDeployer.creationCodeMetaProxy(eulerSwapImpl, abi.encode(poolParams));
(address hookAddress, bytes32 salt) = HookMiner.find(address(eulerSwapFactory), flags, creationCode);

// Deploy pool via EVC
IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
items[0] = IEVC.BatchItem({
    onBehalfOfAccount: address(0),
    targetContract: address(evc),
    value: 0,
    data: abi.encodeCall(evc.setAccountOperator, (user0, hookAddress, true))
});
items[1] = IEVC.BatchItem({
    onBehalfOfAccount: user0,
    targetContract: address(eulerSwapFactory),
    value: 0,
    data: abi.encodeCall(IEulerSwapFactory.deployPool, (poolParams, initialState, salt))
});
evc.batch(items);
```

## Important Notes

1. **Salt is Pool-Specific**: The salt depends on the exact pool parameters. If you change any parameter (vaults, reserves, fees, etc.), you need to mine a new salt.

2. **Deterministic Addresses**: On fresh anvil with deterministic addresses, the same pool parameters will always require the same salt.

3. **HookMiner Limits**: HookMiner tries up to 160,444 iterations to find a valid salt. If it fails, you may need to adjust your pool parameters slightly.

4. **Performance**: Salt mining typically takes a few seconds to find a valid salt among ~80k attempts.

## Troubleshooting

- **"HookAddressNotValid" Error**: The pool address doesn't have the correct permission bits. Use HookMiner to find a valid salt.

- **"Could not find salt" Error**: HookMiner couldn't find a valid salt within its iteration limit. Try adjusting pool parameters slightly (e.g., change fee by 1 wei).

- **Deployment Succeeds but Pool Not Found**: Check that you're using the correct euler account and that the operator was set properly.

## Production Recommendations

For production use:
1. Use the EulerSwap UI which handles salt mining automatically
2. Use the EulerSwap SDK which includes salt mining utilities
3. Pre-mine salts for common pool configurations