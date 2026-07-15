# Contracts

The Solidity workspace is a Foundry project configured for Base Sepolia. It contains a fixed-price, native-asset launchpad protocol; bonding-curve pricing is intentionally not implemented.

## Protocol

- `SherwoodFactory` deploys an ERC-20 token plus an EIP-1167 `LaunchProject` clone, records immutable launch configuration, and owns the fee and implementation settings.
- `SherwoodToken` is an OpenZeppelin ERC-20 with burn and permit support. Only its immutable factory can mint; token ownership belongs to the launch creator.
- `LaunchProject` progresses through `Pending → Live → Graduated | Cancelled`. Buyers can buy and sell unclaimed allocation during a live sale, claim tokens after graduation, or claim a refund after cancellation.
- Protocol fees and creator proceeds cannot leave the project until graduation. This preserves every buyer refund if a launch is cancelled.

## Install dependencies

OpenZeppelin and forge-std are vendored in `lib/` for reproducible builds.

## Commands

```bash
forge build
forge test
forge script scripts/DeploySherwood.s.sol:DeploySherwood --rpc-url base_sepolia --broadcast --verify
```

Copy `.env.example` to `.env` and load it into your shell before a deployment. Never commit private keys.
