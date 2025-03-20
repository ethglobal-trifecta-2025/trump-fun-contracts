// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {BettingContract} from "../src/BettingContract.sol";

contract DeployScript is Script {
    function run() public returns (BettingContract) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Check if USDC_ADDRESS is set
        try vm.envAddress("USDC_ADDRESS") returns (address usdcAddress) {
            // Check if POINTS_TOKEN_ADDRESS is set
            try vm.envAddress("POINTS_TOKEN_ADDRESS") returns (address pointsTokenAddress) {
                console.log("Deploying BettingContract with:");
                console.log("  USDC Address:", usdcAddress);
                console.log("  Points Token Address:", pointsTokenAddress);

                vm.startBroadcast(deployerPrivateKey);
                BettingContract bettingContract = new BettingContract(usdcAddress, pointsTokenAddress);
                vm.stopBroadcast();

                console.log("BettingContract deployed at:", address(bettingContract));
                return bettingContract;
            } catch {
                console.log("Error: POINTS_TOKEN_ADDRESS environment variable not set");
                revert("POINTS_TOKEN_ADDRESS not set");
            }
        } catch {
            console.log("Error: USDC_ADDRESS environment variable not set");
            revert("USDC_ADDRESS not set");
        }
    }
}
