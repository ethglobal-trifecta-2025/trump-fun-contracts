// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {BettingContract} from "../src/BettingContract.sol";

contract GradePoolScript is Script {
    function run(uint256 poolId, uint256 responseOption) public {
        // Get private key from env - needs to be the owner's key
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get the contract address
        try vm.envAddress("BETTING_CONTRACT_ADDRESS") returns (address contractAddress) {
            BettingContract bettingContract = BettingContract(contractAddress);

            // Log the grading operation
            console.log("Grading pool:");
            console.log("  Pool ID:", poolId);
            console.log("  Response Option:", responseOption);
            console.log("  Contract:", contractAddress);

            // Validate response option
            if (responseOption > 2) {
                console.log("Error: Invalid response option. Must be 0 (option 0), 1 (option 1), or 2 (draw)");
                revert("Invalid response option");
            }

            vm.startBroadcast(ownerPrivateKey);

            // Grade the bet
            bettingContract.gradeBet(poolId, responseOption);

            vm.stopBroadcast();

            console.log("Successfully graded pool", poolId, "with option", responseOption);

            // Log the meaning of the response option
            if (responseOption == 0) {
                console.log("Option 0 selected as winner");
            } else if (responseOption == 1) {
                console.log("Option 1 selected as winner");
            } else if (responseOption == 2) {
                console.log("Pool marked as a draw (refunds will be processed)");
            }
        } catch {
            console.log("Error: BETTING_CONTRACT_ADDRESS environment variable not set");
            revert("BETTING_CONTRACT_ADDRESS not set");
        }
    }
}
