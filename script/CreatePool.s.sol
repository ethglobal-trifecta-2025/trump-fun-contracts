// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {BettingContract} from "../src/BettingContract.sol";

contract CreatePoolScript is Script {
    function run() public {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get contract address from environment
        try vm.envAddress("BETTINGPOOLS_CONTRACT_ADDRESS") returns (address contractAddress) {
            // Hardcoded pool parameters instead of using environment variables
            uint256 timestamp = block.timestamp;

            // Add timestamp to question to make it unique
            string memory question = string(
                abi.encodePacked(
                    "Will I WIN the case against the CORRUPT NY Attorney General? The case is RIGGED but the PEOPLE know the TRUTH! (",
                    vm.toString(timestamp),
                    ")"
                )
            );
            string[2] memory options = ["YES, TOTAL VICTORY!", "NO, DEEP STATE WINS"];
            uint40 betsCloseAt = uint40(block.timestamp + 7 days);
            string memory closureCriteria = "When the NY court issues its final ruling on the case";
            string memory closureInstructions =
                "Grade YES if Trump wins the case or it is dismissed. Grade NO if Trump loses the case.";

            console.log("Creating pool with:");
            console.log("  Question:", question);
            console.log("  Option 0:", options[0]);
            console.log("  Option 1:", options[1]);
            console.log("  Bets Close At:", betsCloseAt);
            console.log("  Contract:", contractAddress);

            BettingContract.CreatePoolParams memory params = BettingContract.CreatePoolParams({
                question: question,
                options: options,
                betsCloseAt: betsCloseAt,
                closureCriteria: closureCriteria,
                closureInstructions: closureInstructions
            });

            BettingContract bettingContract = BettingContract(contractAddress);

            vm.startBroadcast(ownerPrivateKey);
            uint256 poolId = bettingContract.createPool(params);
            vm.stopBroadcast();

            console.log("Created pool with ID:", poolId);
        } catch {
            console.log("Error: BETTINGPOOLS_CONTRACT_ADDRESS environment variable not set");
            revert("BETTINGPOOLS_CONTRACT_ADDRESS not set");
        }
    }
}
