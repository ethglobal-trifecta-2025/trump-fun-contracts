// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {BettingContract} from "../src/BettingContract.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PlaceBetScript is Script {
    function run(uint256 poolId, uint256 optionIndex, uint256 amount, uint256 tokenTypeInt) public {
        // Get private key from env
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get the contract address - using BETTINGPOOLS_CONTRACT_ADDRESS instead of CONTRACT_ADDRESS
        try vm.envAddress("BETTINGPOOLS_CONTRACT_ADDRESS") returns (address contractAddress) {
            address bettor = vm.addr(userPrivateKey);
            BettingContract.TokenType tokenType = BettingContract.TokenType(tokenTypeInt);

            BettingContract bettingContract = BettingContract(contractAddress);

            // Approve token transfer
            ERC20 token;
            if (tokenType == BettingContract.TokenType.USDC) {
                token = ERC20(address(bettingContract.usdc()));
            } else {
                token = ERC20(address(bettingContract.pointsToken()));
            }

            console.log("Placing bet:");
            console.log("  Pool ID:", poolId);
            console.log("  Option:", optionIndex);
            console.log("  Amount:", amount);
            console.log("  Token Type:", tokenTypeInt);
            console.log("  Bettor:", bettor);
            console.log("  Contract:", contractAddress);

            vm.startBroadcast(userPrivateKey);

            // Approve token spending
            token.approve(contractAddress, amount);

            // Place bet
            uint256 betId = bettingContract.placeBet(poolId, optionIndex, amount, bettor, tokenType);

            vm.stopBroadcast();

            console.log("Successfully placed bet with ID:", betId);
        } catch {
            console.log("Error: BETTINGPOOLS_CONTRACT_ADDRESS environment variable not set");
            revert("BETTINGPOOLS_CONTRACT_ADDRESS not set");
        }
    }
}
