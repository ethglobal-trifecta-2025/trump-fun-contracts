// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {BettingContract} from "../src/BettingContract.sol";

contract WithdrawScript is Script {
    function run(uint256 betId) public {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get contract address from environment
        try vm.envAddress("BETTINGPOOLS_CONTRACT_ADDRESS") returns (address contractAddress) {
            BettingContract bettingContract = BettingContract(contractAddress);

            console.log("Withdrawing bet:");
            console.log("  Bet ID:", betId);
            console.log("  User:", vm.addr(userPrivateKey));
            console.log("  Contract:", contractAddress);

            vm.startBroadcast(userPrivateKey);
            //TODO Below is messed up, you should check balance and then withdraw and take token type as input
            bettingContract.withdraw(BettingContract.TokenType.USDC, 1000000000000000000);
            vm.stopBroadcast();

            console.log("Withdrawal successful");
        } catch {
            console.log("Error: BETTINGPOOLS_CONTRACT_ADDRESS environment variable not set");
            revert("BETTINGPOOLS_CONTRACT_ADDRESS not set");
        }
    }
}
