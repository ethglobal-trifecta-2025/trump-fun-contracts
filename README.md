# THIS IS A BRANCH STAGING FIXES SHOULD WE BE SELECTED AS FINALISTS, PLEASE DO NOT MERGE THIS BRANCH INTO MAIN, PLEASE DO NOT INCLUDE IN JUDGING

## If you see the above in main and Trifecta is ongoing, roll back whatever you did

## If you see the above in main and Trifecta is over, please delete it

# Trump.fun Prediction Market Platform

An on-chain prediction market platform designed for placing bets on Trump's social media posts and his public actions.

## 📝 Overview

Trump.fun is a decentralized prediction market focused on events related to Donald Trump where users to bet on various outcomes related to Trump's social media posts, reflecting his public statements, and political actions. It leverages account abstraction via Privy for a seamless web3 experience.

## 🔑 Key Features

- Bet on Trump-specific prediction markets
- Minimum bet amount of 1 USD in value
- First-person Trump-style UX/UI

## 📚 Technical Stack

- **Network**: Base Sepolia (testnet)
- **Smart Contracts**: Solidity 0.8.24
- **Development Framework**: Foundry

## 🏗️ Contract Architecture

The platform consists of several smart contracts that work together:

1. **BettingContract**: Manages prediction markets, handles bet placement, and processes payouts
2. **PointsToken**: ERC20 token used for betting on the platform
3. **TrumpFunPaymaster**: Enables gas fee payment in USDC or PointsToken via ERC-4337 account abstraction

## 📊 Deployed Contracts (Base Sepolia)

| Contract | Address | Description |
|----------|---------|-------------|

| PointsToken | `0xA373482b473E33B96412a6c0cA8B847E6BBB4D0d` | Native platform token |
| USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | USD Coin on Base Sepolia |
| BettingContract | `0x2E180501D3D68241dd0318c68fD9BE0AF1D519a1` | Manages prediction markets |
| TrumpFunPaymaster | `0x9031A3eB126892EE71F8A332feb04Ab1f313aB48` | Enables gas payments in USDC/PointsToken |

## 🎲 Betting Contract Flow

The betting process follows these steps:

1. **Market Creation**
   - Admin creates a new prediction market
   - Sets market parameters (description, expiry, options)
   - Market enters OPEN state

2. **Bet Placement**
   - User approves token spending (USDC/PointsToken)
   - User selects an option and bet amount
   - BettingContract validates:
     - Market is OPEN
     - Bet amount meets minimum (1 USD)
     - User has sufficient balance
   - Bet is recorded and tokens are transferred to contract

3. **Market Resolution**
   - Admin resolves market after expiry or when the action is complete.
   - AI agents sets the winning option
   - Market enters RESOLVED state

4. **Payout Processing**
   - Winners can claim their payouts
   - Payout = (User's bet / Total winning bets) * Total pool
   - Platform fee (3%) is deducted
   - Remaining funds distributed to winners

### Setting Up the Development Environment

1. Clone the repository

   ```bash
   git clone https://github.com/your-username/trump-fun-contracts.git
   cd trump-fun-contracts
   ```

2. Install dependencies

   ```bash
   forge install
   ```

3. Set up environment variables

   ```bash
   cp .env.example .env
   # Edit .env with your own values
   ```

4. Compile contracts

   ```bash
   forge build
   ```

5. Run tests

   ```bash
   forge test
   ```

### Deploying Contracts

To deploy the TrumpFunPaymaster contract:

```bash
# Load environment variables
source .env

# Deploy the contract
forge script script/EndToEndTest.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --fork-url $BASE_SEPOLIA_RPC_URL
```

### Using Management Scripts

#### Grading a Pool

To grade a prediction market pool (set the winning option):

```bash
# Grade pool ID 84 with option 0 as the winner
forge script script/GradePoolSimple.s.sol:GradePoolSimpleScript --sig "run(uint256,uint256)" 84 0 --fork-url $BASE_SEPOLIA_RPC_URL --chain base-sepolia --broadcast -vvv
```

The first argument is the pool ID, and the second argument is the winning option (0 or 1, or 2 for a draw).

#### Claiming Payouts for a Pool

To claim payouts for all bets in a specific pool:

```bash
# Claim payouts for all bets in pool ID 84
forge script script/ClaimPoolPayouts.s.sol --sig "run(uint256)" 84 --rpc-url $BASE_SEPOLIA_RPC_URL --chain base-sepolia --broadcast -vvv
```

This script automatically finds all bets in the specified pool and processes their payouts.
