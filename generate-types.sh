#!/bin/bash

# Check if wagmi CLI is installed globally
if ! command -v wagmi &> /dev/null; then
    echo "wagmi CLI not found, installing..."
    bun install --global @wagmi/cli
fi

# Build contracts first
echo "Building contracts..."
forge build

# Create types directory if it doesn't exist
mkdir -p types

# Generate types using wagmi CLI
echo "Generating types..."
wagmi generate

# Copy generated types to frontend and backend
echo "Copying types to frontend and backend..."
cp types/generated.ts ../trump-fun-frontend/src/lib/contract.types.ts
cp types/generated.ts ../trump-fun-agent/src/types/contract.types.ts 

echo "✨ Types generated and copied successfully!" 