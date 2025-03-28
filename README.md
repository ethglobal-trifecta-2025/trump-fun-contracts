# Trump.fun Smart Contracts

![Trump.fun Logo](https://fxewzungnacaxpsnowcu.supabase.co/storage/v1/object/public/trump-fun/logo/trump.fun.logo.jpg)

On-chain prediction market platform designed for placing bets on Trump's social media posts and public actions.

## 📝 Overview

Trump.fun is an AI-powered prediction market platform centered around President Trump's actions and statements. Our system automatically creates betting pools based on Trump's Truth Social posts, allowing users to place bets using either cryptocurrency (USDC) or our platform's native FREEDOM tokens.

The contracts component provides the blockchain infrastructure that powers the platform's betting functionality, token management, and account abstraction features.

## 🔑 Key Features

- Decentralized prediction markets focused on Trump-specific events
- Support for both USDC and native FREEDOM token betting
- Minimum bet amount of 1 USD in value
- 3% platform fee with transparent payout distribution
- Account abstraction via Privy for seamless web3 experience
- Automated market creation and resolution through AI agents

## 📚 Technical Stack

- **Network**: Base Sepolia (testnet)
- **Smart Contracts**: Solidity 0.8.24
- **Development Framework**: Foundry
- **Account Abstraction**: ERC-4337 standard

## 🏗️ Contract Architecture

The platform consists of several smart contracts that work together:

1. **BettingContract**: Manages prediction markets, handles bet placement, and processes payouts
2. **PointsToken**: ERC20 token (FREEDOM) used for betting on the platform
3. **TrumpFunPaymaster**: Enables gas fee payment in USDC or PointsToken via ERC-4337 account abstraction

## 📊 Deployed Contracts (Base Sepolia)

| Contract | Address | Description |
|----------|---------|-------------|
| PointsToken | `0xA373482b473E33B96412a6c0cA8B847E6BBB4D0d` | Native platform token (FREEDOM) |
| USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | USD Coin on Base Sepolia |
| BettingContract | `0x2E180501D3D68241dd0318c68fD9BE0AF1D519a1` | Manages prediction markets |
| TrumpFunPaymaster | `0x9031A3eB126892EE71F8A332feb04Ab1f313aB48` | Enables gas payments in USDC/FREEDOM |

## 🎲 Betting Contract Flow

The betting process follows these steps:

1. **Market Creation**
   - AI agent identifies a potential betting opportunity from Trump's posts
   - Smart contract creates a new prediction market
   - Sets market parameters (description, expiry, options)
   - Market enters OPEN state

2. **Bet Placement**
   - User approves token spending (USDC/FREEDOM)
   - User selects an option and bet amount
   - BettingContract validates:
     - Market is OPEN
     - Bet amount meets minimum (1 USD)
     - User has sufficient balance
   - Bet is recorded and tokens are transferred to contract

3. **Market Resolution**
   - AI agent monitors real-world events to determine outcomes
   - Agent triggers market resolution after expiry or when the action is complete
   - Sets the winning option based on verifiable events
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

## Deploying Contracts

To deploy the contracts:

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

## Contract Integration

These contracts integrate with:
- Frontend interface for user interactions
- AI agents for market creation and resolution
- Telegram bot for additional platform access

## Social Media

- Twitter: [@realTrumpFun](https://x.com/realTrumpFun)
- Truth Social: [@realDonaldTrump](https://truthsocial.com/@realDonaldTrump)
- Telegram: [trump_fun_bot](https://t.me/trump_fun_bot)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.
