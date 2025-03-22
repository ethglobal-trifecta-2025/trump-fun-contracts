# Trump.fun Prediction Market Platform

An on-chain prediction market platform designed for placing bets on Trump's social media posts and his public actions.

## 📝 Overview

Trump.fun is a decentralized prediction market focused on events related to Donald Trump where users to bet on various outcomes related to Trump's social media posts, reflecting his public statements, and political actions. It leverages account abstraction via Privy for a seamless web3 experience, and allows users to place bets using either custom USDC or the platform's native PointsToken.

## 🔑 Key Features

- Bet on Trump-specific prediction markets
- Pay transaction fees in USDC or PointsToken (no ETH needed)
- Smart contract-powered markets with transparent resolution
- Embedded wallet support through Privy
- Minimum bet amount of 1 USD in value
- First-person Trump-style UX/UI

## 📚 Technical Stack

- **Network**: Base Sepolia (testnet) 
- **Smart Contracts**: Solidity 0.8.24
- **Development Framework**: Foundry
- **Account Abstraction**: ERC-4337 via EntryPoint and a custom Paymaster

## 🏗️ Contract Architecture

The platform consists of several smart contracts that work together:

1. **BettingContract**: Manages prediction markets, handles bet placement, and processes payouts
2. **PointsToken**: ERC20 token used for betting on the platform
3. **TrumpFunPaymaster**: Enables gas fee payment in USDC or PointsToken via ERC-4337 account abstraction

## 📊 Deployed Contracts (Base Sepolia)

| Contract | Address | Description |
|----------|---------|-------------|
| TrumpFunPaymaster | `0x9031A3eB126892EE71F8A332feb04Ab1f313aB48` | Enables gas payments in USDC/PointsToken |
| PointsToken | `0xA373482b473E33B96412a6c0cA8B847E6BBB4D0d` | Native platform token |
| USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | USD Coin on Base Sepolia |
| BettingContract | `0x20e975516Fae905839F61754778483ecEA7EB403` | Manages prediction markets |
| EntryPoint (ERC-4337) | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` | Main entry point for account abstraction |

## 🔄 Account Abstraction Flow

The platform uses ERC-4337 account abstraction to provide a gas-less experience for users:

1. User initiates a transaction (e.g., placing a bet)
2. Privy wallet creates a UserOperation
3. UserOperation includes the TrumpFunPaymaster address and token choice (USDC/PointsToken)
4. The EntryPoint contract validates the operation and executes it
5. The Paymaster pays for gas in ETH but charges the user in their chosen token

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
forge script script/DeployPaymaster.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --fork-url $BASE_SEPOLIA_RPC_URL
```

