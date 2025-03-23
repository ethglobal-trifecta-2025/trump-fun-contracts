// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {BettingContract} from "../src/BettingContract.sol";
import {console} from "forge-std/console.sol";

/**
 * @title ClaimPoolPayouts
 * @notice Script to get all bets for a given pool and call claimPayouts on them
 * @dev Usage: forge script script/ClaimPoolPayouts.s.sol --sig "run(uint256)" <POOL_ID> --rpc-url <RPC_URL> --broadcast --verify -vvvv
 * Required env variables:
 * - BETTING_CONTRACT: The address of the deployed BettingContract
 */
contract ClaimPoolPayouts is Script {
    BettingContract public bettingContract;

    function run(uint256 poolId) external {
        address contractAddress = vm.envAddress("BETTING_CONTRACT_ADDRESS");

        // Get the betting contract
        bettingContract = BettingContract(contractAddress);

        console.log("Claiming payouts for Pool ID:", poolId);

        // We'll use a contract trace call to extract the bet IDs
        // First, get all emitted BetPlaced events for this pool
        uint256[] memory betIds = getBetIdsFromEvents(poolId);

        console.log("Found", betIds.length, "bets to process");

        // Start broadcasting transactions
        vm.startBroadcast();

        // Claim payouts for all bets in the pool
        bettingContract.claimPayouts(betIds);

        vm.stopBroadcast();

        console.log("Finished claiming payouts for Pool ID:", poolId);
    }

    /**
     * @notice Gets all bet IDs for a pool by querying event logs
     * @param poolId The ID of the pool to get bets for
     * @return betIds Array of bet IDs for the pool
     */
    function getBetIdsFromEvents(uint256 poolId) internal view returns (uint256[] memory) {
        // This is a simplified approach - in a real implementation,
        // you might need to handle pagination for large numbers of events

        // Get the number of bets by reading storage directly using VM cheatcode
        bytes32 betIdsSlot = keccak256(abi.encode(poolId, uint256(15))); // Slot for betIds array length
        uint256 betCount = uint256(vm.load(address(bettingContract), betIdsSlot));

        console.log("Total bets found:", betCount);

        // Now create an array to hold all bet IDs
        uint256[] memory betIds = new uint256[](betCount);

        // Read each bet ID from storage
        for (uint256 i = 0; i < betCount; i++) {
            // Calculate slot for each betId in the array
            // For dynamic arrays, the elements are stored at keccak256(slot) + index
            bytes32 arrayStartSlot = keccak256(abi.encode(betIdsSlot));
            bytes32 betIdSlot = bytes32(uint256(arrayStartSlot) + i);
            uint256 betId = uint256(vm.load(address(bettingContract), betIdSlot));
            betIds[i] = betId;
            console.log("Bet ID:", betId);
        }

        return betIds;
    }
}
