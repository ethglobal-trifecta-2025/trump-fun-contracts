// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/TrumpFunPaymaster.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract DeployPaymaster is Script {
    // Base Sepolia network addresses
    address constant POINTS_TOKEN_ADDRESS = 0xA373482b473E33B96412a6c0cA8B847E6BBB4D0d;
    address constant USDC_ADDRESS = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    // Entry point address on Base Sepolia
    // Note: You'll need to replace this with the correct EntryPoint address on Base Sepolia
    address constant ENTRY_POINT_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy TrumpFunPaymaster
        TrumpFunPaymaster paymaster =
            new TrumpFunPaymaster(IEntryPoint(ENTRY_POINT_ADDRESS), IERC20(POINTS_TOKEN_ADDRESS), IERC20(USDC_ADDRESS));

        // Add deposit to the Paymaster (1.5 ETH as requested)
        paymaster.deposit{value: 1.5 ether}();

        // Add stake if needed for validation
        // paymaster.addStake{value: 1 ether}(86400); // 1 day unstake delay

        console.log("TrumpFunPaymaster deployed at:", address(paymaster));
        console.log("Deposit added: 1.5 ether");

        vm.stopBroadcast();
    }
}
