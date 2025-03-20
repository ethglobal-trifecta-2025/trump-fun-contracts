#!/bin/bash

# Load environment variables
set -a
source .env
set +a

echo "Deploying PointsToken..."
echo "RPC_URL: $RPC_URL"
echo "ETHERSCAN_API_KEY: $ETHERSCAN_API_KEY"

# Deploy the PointsToken contract
forge script script/DeployPoints.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --verifier-url $VERIFIER_URL --etherscan-api-key $ETHERSCAN_API_KEY --verify

# Get the address manually from the console output
echo "The PointsToken contract address should be displayed in the output above."
echo "Please copy the address and update your .env file manually with:"
echo "POINTS_TOKEN_ADDRESS=\"your_contract_address_here\""

# Verify Points Token if needed
if [ "$VERIFY_POINTS_TOKEN" = "true" ] && [ -n "$POINTS_TOKEN_ADDRESS" ]; then
    echo "Verifying PointsToken contract..."
    forge verify-contract $POINTS_TOKEN_ADDRESS src/PointsToken.sol:PointsToken \
        --constructor-args $(cast abi-encode "constructor(string,string,uint8,uint256)" "Betting Points" "BPTS" 18 1000000000000000000000000000) \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --chain $CHAIN_ID \
        --verifier-url $VERIFIER_URL
    
    echo "PointsToken verification attempted. Check Etherscan for confirmation."
else
    echo "Skipping verification or missing POINTS_TOKEN_ADDRESS."
fi 