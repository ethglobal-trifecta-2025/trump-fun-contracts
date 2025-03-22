// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BettingContract} from "../src/BettingContract.sol";

contract GradePoolScript is Script {
    // Define the parameters to be passed from the command line
    uint256 public poolId;
    uint256 public responseOption;
    uint256 public ownerPrivateKey;
    BettingContract public bettingContract;
    address public constant BETTING_CONTRACT = 0x2E180501D3D68241dd0318c68fD9BE0AF1D519a1;
    


    function setUp() public {
        // Get owner's private key
        ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Initialize contract
        bettingContract = BettingContract(BETTING_CONTRACT);
        
        // Log current state
        console.log("Contract address:", address(bettingContract));
        console.log("Next pool ID:", bettingContract.nextPoolId());
    }

    function run() public {
        // Get pool ID and response option from environment
        poolId = vm.envUint("POOL_ID");
        responseOption = vm.envUint("RESPONSE_OPTION");

        // Log grading information
        console.log("Grading pool", poolId, "with response option", responseOption);

        // Get pool info first
        (
            uint256 id,
            string memory question,
            uint40 betsCloseAt,
            uint256 winningOption,
            BettingContract.PoolStatus status,
            bool isDraw,
            uint256 createdAt,
            string memory closureCriteria,
            string memory closureInstructions,
            string memory originalTruthSocialPostId
        ) = bettingContract.pools(poolId);

        // Log pool info
        console.log("Pool ID:", id);
        console.log("Question:", question);
        console.log("Pool Status:", uint8(status)); // 0 = NONE, 1 = PENDING, 2 = GRADED
        console.log("Bets Close At:", betsCloseAt);
        console.log("Current Time:", block.timestamp);

        // Check if pool exists and is in correct state
        require(id > 0, "Pool does not exist");
        require(status == BettingContract.PoolStatus.PENDING, "Pool is not in PENDING status");
        require(responseOption <= 2, "Invalid response option (must be 0, 1, or 2)");

        // Start broadcasting transactions
        vm.startBroadcast(ownerPrivateKey);
        
        // Grade the pool
        bettingContract.gradeBet(poolId, responseOption);
        console.log("Successfully graded pool", poolId, "with response option", responseOption);
        
        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}