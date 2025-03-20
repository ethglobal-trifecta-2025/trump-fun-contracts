# Trump.fun Betting Contracts

Smart contracts for managing Trump.fun prediction markets with support for both USDC and Points tokens.

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

<https://book.getfoundry.sh/>

## Betting Contract Features

- Create prediction market pools with customizable parameters
- Place bets using either USDC or Points tokens
- Withdraw winnings on demand
- Grade bets and claim payouts

## Points Token

The platform uses a custom ERC20 token (`PointsToken.sol`) as an alternative betting currency. This token has configurable decimals and can be minted by the contract owner to reward users.

### Minting Points

To mint points to a user's address, use the provided script:

```bash
# Mint tokens to an address
./mint-points.sh <recipient_address> <amount> [points_token_address]
```

Example:
```bash
# Mint 100 tokens (with 6 decimals) to an address
./mint-points.sh 0x7956c2C1b85f5aC14c2c537F669B65991428E268 10000000000 $POINTS_TOKEN_ADDRESS
```

The script accepts the following parameters:
- `recipient_address`: The address to receive the tokens (required)
- `amount`: The amount of tokens to mint, adjusted for decimals (required)
- `points_token_address`: The address of the Points Token contract (optional if set in .env)

Requirements:
- The script must be run by the Points Token contract owner
- You need a `.env` file with the following variables:
  - `PRIVATE_KEY`: The private key of the token contract owner
  - `POINTS_TOKEN_ADDRESS`: The address of the deployed Points Token contract (if not provided as argument)
  - `RPC_URL`: The RPC URL for the network where the contract is deployed


## Development Commands

```bash
# Build the contracts
forge build

# Run tests
forge test

# Format code
forge fmt

# Generate gas snapshots
forge snapshot

# Run local node
anvil
```

## Deployment & Interaction

Specify the network using the `--network` flag. Available options:

- `base-sepolia` for Base Sepolia testnet
- `base` for Base mainnet

### Deploying the Points Token

```bash
forge script script/DeployPoints.s.sol --network base-sepolia --broadcast
```

### Deploying the Betting Contract

```bash
# Set in .env: PRIVATE_KEY, USDC_ADDRESS, POINTS_TOKEN_ADDRESS
forge script script/Deploy.s.sol --network base-sepolia --broadcast
```

### Create a Betting Pool

```bash
# Set in .env: PRIVATE_KEY, BETTINGPOOLS_CONTRACT_ADDRESS
forge script script/CreatePool.s.sol --network base-sepolia --broadcast
```

Note: The pool parameters (question, options, etc.) are hardcoded in the CreatePool.s.sol script. Each new pool gets a unique timestamp added to the question text.

### Place a Bet

```bash
# Set in .env: PRIVATE_KEY, BETTINGPOOLS_CONTRACT_ADDRESS
forge script script/PlaceBet.s.sol --network base-sepolia --broadcast --sig "run(uint256,uint256,uint256,uint256)" <pool_id> <option_index> <amount> <token_type>
```

Example:

```bash
# Place a bet on pool ID 1, option 0, for 100 USDC tokens (token type 0)
forge script script/PlaceBet.s.sol --network base-sepolia --broadcast --sig "run(uint256,uint256,uint256,uint256)" 1 0 100000000 0
```

Note: TOKEN_TYPE 0 is for USDC, 1 is for Points token.

### Withdraw Funds

```bash
# Set in .env: PRIVATE_KEY, BETTINGPOOLS_CONTRACT_ADDRESS
forge script script/Withdraw.s.sol --network base-sepolia --broadcast --sig "run(uint256,uint256)" <amount> <token_type>
```

### Contract Verification

```bash
forge verify-contract <deployed_contract_address> BettingContract \
  --constructor-args $(cast abi-encode "constructor(address,address)" <usdc_address> <points_token_address>) \
  --chain-id <chain_id> \
  --verifier-url <basescan_api_url> \
  --api-key ${BASESCAN_API_KEY}
```

Chain IDs:

- Base Sepolia: 84532
- Base Mainnet: 8453

Basescan API URLs:

- Base Sepolia: <https://api-sepolia.basescan.org/api>
- Base Mainnet: <https://api.basescan.org/api>

## License

MIT
