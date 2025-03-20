#!/bin/bash

# Load environment variables
set -a
source .env
set +a

# Check if POINTS_TOKEN_ADDRESS is set
if [ -z "$POINTS_TOKEN_ADDRESS" ]; then
    echo "Error: POINTS_TOKEN_ADDRESS is not set in the .env file"
    echo "Please run deploy-points.sh first and update your .env file"
    exit 1
fi

echo "Deploying BettingContract..."
echo "Using POINTS_TOKEN_ADDRESS: $POINTS_TOKEN_ADDRESS"
echo "Using USDC_ADDRESS: $USDC_ADDRESS"

# Deploy the BettingContract
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --verifier-url $VERIFIER_URL --etherscan-api-key $ETHERSCAN_API_KEY --verify

# Get the address manually from the console output
echo "The BettingContract address should be displayed in the output above."
echo "Please copy the address and update your .env file manually with:"
echo "BETTING_CONTRACT_ADDRESS=\"your_contract_address_here\""

# Verify BettingContract if a BETTING_CONTRACT_ADDRESS is provided
if [ -n "$BETTING_CONTRACT_ADDRESS" ]; then
    echo "Verifying BettingContract..."
    forge verify-contract $BETTING_CONTRACT_ADDRESS src/BettingContract.sol:BettingContract \
        --constructor-args $(cast abi-encode "constructor(address,address)" $USDC_ADDRESS $POINTS_TOKEN_ADDRESS) \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --chain $CHAIN_ID \
        --verifier-url $VERIFIER_URL
    
    echo "BettingContract verification attempted. Check Etherscan for confirmation."
else
    echo "Skipping verification due to missing BETTING_CONTRACT_ADDRESS."
fi

# Optional: Run end-to-end test script
if [ "$RUN_E2E_TEST" = "true" ]; then
    echo "Running end-to-end test script..."
    forge script script/EndToEndTest.s.sol --rpc-url $RPC_URL --broadcast \
        --private-key $PRIVATE_KEY \
        --private-key $ACCOUNT1_PRIVATE_KEY \
        --private-key $ACCOUNT2_PRIVATE_KEY \
        --private-key $ACCOUNT3_PRIVATE_KEY \
        --verifier-url $VERIFIER_URL \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --verify
    
    echo "End-to-end test completed."
fi 