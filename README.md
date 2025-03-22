# TrumpFunPaymaster for Account Abstraction

This repository contains a custom Paymaster contract for the Trump.fun prediction market platform. The Paymaster allows users to pay gas fees using either USDC or PointsToken, making the platform more user-friendly by abstracting away the need for users to hold ETH for gas.

## Overview

The `TrumpFunPaymaster.sol` contract enables:

- Gas fees to be paid in either USDC or PointsToken
- Fixed 1:1 USD exchange rate for both tokens
- Simple integration with Privy wallet infrastructure

## Contract Addresses

- PointsToken: `0xA373482b473E33B96412a6c0cA8B847E6BBB4D0d`
- USDC: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- BettingContract: `0x2E180501D3D68241dd0318c68fD9BE0AF1D519a1`
- EntryPoint: `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789`

## Deployment

To deploy the Paymaster contract:

1. Set up environment variables:
   ```bash
   export PRIVATE_KEY=your_private_key
   export BASE_SEPOLIA_RPC_URL=your_base_sepolia_rpc_url
   ```

2. Deploy using Forge:
   ```bash
   forge script script/DeployPaymaster.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
   ```

## Integration with Privy

Here's how to integrate the Paymaster with your Privy setup in the frontend:

```typescript
import { PrivyProvider, usePrivy } from '@privy-io/react-auth';
import { ethers } from 'ethers';

// Paymaster configuration
const paymasterAddress = 'YOUR_DEPLOYED_PAYMASTER_ADDRESS';
const USDC_ADDRESS = '0x036CbD53842c5426634e7929541eC2318f3dCF7e';
const POINTS_TOKEN_ADDRESS = '0xA373482b473E33B96412a6c0cA8B847E6BBB4D0d';

// Example of how to use the paymaster with Privy
function App() {
  const { user, sendTransaction } = usePrivy();

  // Function to create paymaster data
  const createPaymasterData = (tokenType, maxCost) => {
    // TokenType: 0 for USDC, 1 for PointsToken
    return ethers.utils.defaultAbiCoder.encode(
      ['uint8', 'uint256'],
      [tokenType, maxCost]
    );
  };

  // Example: Place a bet with gas paid in USDC
  const placeBetWithUSDC = async () => {
    if (!user?.wallet) return;
    
    // Approve USDC for the paymaster first
    const usdcContract = new ethers.Contract(
      USDC_ADDRESS,
      ['function approve(address spender, uint256 amount) public returns (bool)'],
      user.wallet.provider
    );
    
    // Approve enough USDC for gas fees (e.g., 5 USDC)
    await usdcContract.approve(paymasterAddress, ethers.utils.parseUnits('5', 6));
    
    // Create paymaster data (using USDC, TokenType = 0)
    const paymasterData = createPaymasterData(0, ethers.utils.parseUnits('5', 6));
    
    // Prepare the user operation with paymaster
    const userOperation = {
      target: 'YOUR_BETTING_CONTRACT_ADDRESS',
      data: 'YOUR_ENCODED_FUNCTION_CALL',
      value: '0',
      // Add paymaster information
      paymasterAndData: ethers.utils.hexConcat([
        paymasterAddress,
        ethers.utils.hexZeroPad(ethers.utils.hexlify(1000000), 16), // Gas limit
        ethers.utils.hexZeroPad(ethers.utils.hexlify(1000000), 16), // Verification gas limit
        paymasterData
      ])
    };
    
    // Send the transaction
    const txHash = await sendTransaction(userOperation);
    console.log('Transaction sent:', txHash);
  };
  
  // Similarly for PointsToken
  const placeBetWithPointsToken = async () => {
    // Similar to above but use TokenType = 1 for PointsToken
    const paymasterData = createPaymasterData(1, ethers.utils.parseUnits('5', 6));
    // Rest of the implementation is similar
  };
  
  return (
    <div>
      {/* Your UI components */}
      <button onClick={placeBetWithUSDC}>Place Bet with USDC Gas</button>
      <button onClick={placeBetWithPointsToken}>Place Bet with Points Gas</button>
    </div>
  );
}

// Wrap your application with PrivyProvider
const AppWithPrivy = () => (
  <PrivyProvider
    appId="YOUR_PRIVY_APP_ID"
    config={{
      // Configure Privy for Base network
      embeddedWallets: {
        createOnLogin: 'all-users',
        noPromptOnSignature: true
      },
      defaultChain: 'base-sepolia',
      supportedChains: ['base-sepolia', 'base']
    }}
  >
    <App />
  </PrivyProvider>
);

export default AppWithPrivy;
```

## Key Features

1. **Multi-Token Support**: Users can choose between USDC or PointsToken for gas fees.
2. **Fixed Exchange Rate**: Both tokens are valued at 1:1 with USD.
3. **Gas Price Markups**: The contract applies a configurable markup (default 3%) to account for price fluctuations.
4. **Owner Controls**: The contract owner can adjust gas price markups and minimum deposit requirements.

## Functions

- `validatePaymasterUserOp`: Validates user operations and checks if the user has enough tokens.
- `postOp`: Handles post-operation processing, charging users for gas in their chosen token.
- `convertEthToToken`: Converts ETH gas costs to token amounts.
- Various administrative functions to manage deposits and stakes.

## Security Considerations

- The Paymaster contract requires sufficient ETH deposits in the EntryPoint contract.
- Users must approve the Paymaster to spend their tokens before using it.
- Fixed exchange rates may become outdated; in production, consider using a price oracle.

## License

MIT
