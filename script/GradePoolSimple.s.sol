// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {BettingContract} from "../src/BettingContract.sol";

contract GradePoolSimpleScript is Script {
    // Define the parameters
    BettingContract public bettingContract;
    address public constant BETTING_CONTRACT = 0x2E180501D3D68241dd0318c68fD9BE0AF1D519a1;

    function setUp() public {
        // Get owner's private key
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Initialize contract
        bettingContract = BettingContract(BETTING_CONTRACT);

        // Log current state
        console2.log("BettingContract address:", address(bettingContract));
        console2.log("Next pool ID:", bettingContract.nextPoolId());
    }

    function run(uint256 poolId, uint256 responseOption) public {
        setUp();

        // Log grading information
        console2.log("Grading pool", poolId, "with response option", responseOption);
        console2.log("Current Time:", block.timestamp);

        // For simplicity, we'll just validate the responseOption and proceed with grading
        require(responseOption <= 2, "Invalid response option (must be 0, 1, or 2)");

        // Start broadcasting transactions
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);

        // Grade the pool
        bettingContract.gradeBet(poolId, responseOption);
        console2.log("Successfully graded pool", poolId, "with response option", responseOption);

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
