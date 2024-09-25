# <h1 align="center"> Token Chain Migration Project </h1>

This project implements a cross-chain token migration system for migrating tokens from one blockchain to another. It is built on top of LayerZero, enabling seamless communication between different blockchains (such as BNB and Polygon). The system allows users to swap old versions of tokens on one chain for new versions on another chain, with various options for vesting and bonuses.

The project consists of two main smart contracts:

1. **CrossChainSwap**:

   - Manages the token swap process, allowing users to swap tokens from one chain to another with different vesting options and bonuses.
   - Supports multiple swap options, including a direct 1:1 transfer with no vesting or bonuses (Option 3).
   - Tracks the total amount of swapped tokens and ensures the proper handling of token transfers and cross-chain messaging.

2. **CrossChainVesting**:
   - Manages the vesting schedules for tokens swapped across chains.
   - Supports vesting options with different cliff periods, bonuses, and durations.
   - Handles the release of vested tokens and allows for the claiming of tokens under Option 3 after a specific event (TGE).
   - Provides a mechanism for the owner to withdraw excess tokens from the contract after covering all vesting and claimable amounts.

This project is designed to ensure a smooth and secure migration of tokens between chains while providing flexible vesting options for users. The contracts include additional functionality for tracking total swapped tokens, managing vesting schedules, and handling token claims post-TGE.

## Usage

Install Foundry and Forge: [installation guide](https://book.getfoundry.sh/getting-started/installation)

### Setup:

```bash
git clone <repo_link>
```

### Install dependencies:

```bash
forge install
```

### Compile contracts:

```shell
make build
```

### Run unit tests:

```shell
make test
```

### Add required .env variables:

```bash
cp .env.example .env
```

### Execute swap script:

```bash
make execute-swap
```

---
### Monitor Omnichain Transactions: 

- [LayerZero Scan](https://testnet.layerzeroscan.com/): View and track cross-chain transactions in real-time.
- [LayerZero Docs](https://docs.layerzero.network/v2/developers/evm/tooling/layerzeroscan): Learn more about LayerZero's omnichain infrastructure and available developer tools.
---

<h2> Cross Chain Swap & Vesting Contracts </h2>

#### BNB CHAIN TESTNET:

| Name             | Address                                                                                                                      |
| :--------------- | :--------------------------------------------------------------------------------------------------------------------------- |
| ARTCOIN_BEP20    | [0xF3B5E392278C3Ff61C5E6eBE14aC9EB5EdEb976a](https://testnet.bscscan.com/address/0xF3B5E392278C3Ff61C5E6eBE14aC9EB5EdEb976a) |
| CROSS_CHAIN_SWAP | [0x297571610EEB63136a796fC717952017BC3A6774](https://testnet.bscscan.com/address/0x297571610EEB63136a796fC717952017BC3A6774) |

#### POLYGON TESTNET:

| Name                | Address                                                                                                                        |
| :------------------ | :----------------------------------------------------------------------------------------------------------------------------- |
| ARTCOIN_ERC20       | [0x234aFAFa5507042BD05D8f42454616BA103004B1](https://amoy.polygonscan.com/address/0x234aFAFa5507042BD05D8f42454616BA103004B1) |
| CROSS_CHAIN_VESTING | [0xE3351140F9D2060Df71B458657099beA83b095C0](https://amoy.polygonscan.com/address/0xE3351140F9D2060Df71B458657099beA83b095C0) |
