// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PointsToken} from "../src/PointsToken.sol";

contract MintPointsScript is Script {
    function run(address recipient, uint256 amount, address pointsTokenAddress) public {
        if (recipient == address(0)) {
            console.log("Error: Recipient address cannot be zero address");
            revert("Recipient address is zero");
        }

        if (pointsTokenAddress == address(0)) {
            console.log("Error: Points token address cannot be zero address");
            revert("Points token address is zero");
        }

        if (amount == 0) {
            console.log("Error: Mint amount cannot be zero");
            revert("Mint amount is zero");
        }

        // Get private key from environment variables for contract owner
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        PointsToken pointsToken = PointsToken(pointsTokenAddress);

        console.log("Minting tokens:");
        console.log("  Recipient:", recipient);
        console.log("  Amount:", amount);
        console.log("  Points Token:", pointsTokenAddress);

        // Mint tokens to the recipient
        vm.startBroadcast(deployerPrivateKey);
        pointsToken.mint(recipient, amount);
        vm.stopBroadcast();

        // Log the results
        console.log("Minted %s tokens to %s", amount, recipient);
        console.log("New balance: %s", pointsToken.balanceOf(recipient));
    }
}
