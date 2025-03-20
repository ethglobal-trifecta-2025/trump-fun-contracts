#!/bin/bash

# Check if .env file exists and source it
if [ -f .env ]; then
    source .env
else
    echo "No .env file found. Please create one based on .env.example"
    exit 1
fi

# Check if required parameters are provided
if [ -z "$1" ]; then
    echo "Error: Recipient address not provided"
    echo "Usage: ./mint-points.sh <recipient_address> <amount> [points_token_address]"
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: Amount not provided"
    echo "Usage: ./mint-points.sh <recipient_address> <amount> [points_token_address]"
    exit 1
fi

# Get points token address from parameter or .env
POINTS_TOKEN_ADDRESS=${3:-$POINTS_TOKEN_ADDRESS}

if [ -z "$POINTS_TOKEN_ADDRESS" ]; then
    echo "Error: Points token address not provided and POINTS_TOKEN_ADDRESS not set in .env file"
    echo "Usage: ./mint-points.sh <recipient_address> <amount> [points_token_address]"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set in .env file"
    exit 1
fi

if [ -z "$RPC_URL" ]; then
    echo "Error: RPC_URL not set in .env file"
    exit 1
fi

RECIPIENT_ADDRESS=$1
MINT_AMOUNT=$2

# Run the forge script
echo "Minting $MINT_AMOUNT tokens to $RECIPIENT_ADDRESS from $POINTS_TOKEN_ADDRESS..."
forge script script/MintPoints.s.sol --rpc-url $RPC_URL --broadcast --sig "run(address,uint256,address)" $RECIPIENT_ADDRESS $MINT_AMOUNT $POINTS_TOKEN_ADDRESS

echo "Done!" 