#!/bin/bash

# Load environment variables
set -a
source .env
set +a

# Deploy PointsToken if POINTS_TOKEN_ADDRESS is not set
echo "POINTS_TOKEN_ADDRESS: $POINTS_TOKEN_ADDRESS"
echo "POINTS_TOKEN_ADDRESS is empty: $([ -z "$POINTS_TOKEN_ADDRESS" ])"
# if [ -z "$POINTS_TOKEN_ADDRESS" ]; then
    echo "Deploying PointsToken..."
    echo "RPC_URL: $RPC_URL"
    echo "ETHERSCAN_API_KEY: $ETHERSCAN_API_KEY"
    
    POINTS_DEPLOYMENT_OUTPUT=$(forge script script/DeployPoints.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --verifier-url $VERIFIER_URL --etherscan-api-key $ETHERSCAN_API_KEY --verify --json)
    echo "POINTS_DEPLOYMENT_OUTPUT: $POINTS_DEPLOYMENT_OUTPUT"
    # Extract the deployed contract address from the output
    POINTS_TOKEN_ADDRESS=$(echo $POINTS_DEPLOYMENT_OUTPUT | jq -r '.deployedTo')
    
    echo "POINTS_TOKEN_ADDRESS: $POINTS_TOKEN_ADDRESS"

    if [ -z "$POINTS_TOKEN_ADDRESS" ] || [ "$POINTS_TOKEN_ADDRESS" == "null" ]; then
        echo "Failed to extract Points Token address from deployment output."
        exit 1
    fi
    
    echo "PointsToken deployed at: $POINTS_TOKEN_ADDRESS"
    
    # Update the .env file with the Points Token address
    if grep -q "POINTS_TOKEN_ADDRESS=" .env; then
        sed -i '' "s/POINTS_TOKEN_ADDRESS=.*/POINTS_TOKEN_ADDRESS=$POINTS_TOKEN_ADDRESS/" .env
    else
        echo "POINTS_TOKEN_ADDRESS=$POINTS_TOKEN_ADDRESS" >> .env
    fi
    
    echo "Environment file updated with Points Token address."
# fi

echo "Deploying BettingContract..."
DEPLOYMENT_OUTPUT=$(forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --verifier-url $VERIFIER_URL --etherscan-api-key $ETHERSCAN_API_KEY --verify --json)

# Extract the deployed contract address from the output
CONTRACT_ADDRESS=$(echo $DEPLOYMENT_OUTPUT | jq -r '.deployedTo')

if [ -z "$CONTRACT_ADDRESS" ] || [ "$CONTRACT_ADDRESS" == "null" ]; then
    echo "Failed to extract contract address from deployment output."
    exit 1
fi

echo "BettingContract deployed at: $CONTRACT_ADDRESS"

# Verify the contract if not already verified during deployment
echo "Verifying contracts on Etherscan..."

# Verify Points Token if needed
if [ "$VERIFY_POINTS_TOKEN" = "true" ]; then
    forge verify-contract $POINTS_TOKEN_ADDRESS src/PointsToken.sol:PointsToken \
        --constructor-args $(cast abi-encode "constructor(string,string,uint8,uint256)" "Betting Points" "BPTS" 18 1000000000000000000000000000) \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --chain $CHAIN_ID
fi

# Verify Betting Contract
forge verify-contract $CONTRACT_ADDRESS src/BettingContract.sol:BettingContract \
    --constructor-args $(cast abi-encode "constructor(address,address)" $USDC_ADDRESS $POINTS_TOKEN_ADDRESS) \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain $CHAIN_ID

echo "Contract verification attempted. Check Etherscan for confirmation."

# Update the .env file with the new contract address
if grep -q "CONTRACT_ADDRESS=" .env; then
    sed -i '' "s/CONTRACT_ADDRESS=.*/CONTRACT_ADDRESS=$CONTRACT_ADDRESS/" .env
else
    echo "CONTRACT_ADDRESS=$CONTRACT_ADDRESS" >> .env
fi

echo "Environment file updated with deployed contract address."

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