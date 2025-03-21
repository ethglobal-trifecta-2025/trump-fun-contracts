// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import "forge-std/console2.sol";
import {PointsToken} from "../src/PointsToken.sol";
import {BettingContract} from "../src/BettingContract.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract EndToEndTest is Script {
    // Contracts
    BettingContract public bettingContract;
    IERC20 public usdcToken;
    PointsToken public pointsToken;

    // Accounts
    address public owner;
    address public account1;
    address public account2;
    address public account3;

    uint256 public ownerPrivateKey;
    uint256 public account1PrivateKey;
    uint256 public account2PrivateKey;
    uint256 public account3PrivateKey;

    // Pool IDs
    uint256[] public poolIds;

    // Bet IDs for each user
    mapping(address => uint256[]) public userBetIds;

    // Constants
    uint256 public constant POINTS_AMOUNT = 10_000 * 10 ** 6; // 10k FREEDOM (assuming 6 decimals)

    function setUp() public {
        // Load private keys from env
        ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        account1PrivateKey = vm.envUint("ACCOUNT1_PRIVATE_KEY");
        account2PrivateKey = vm.envUint("ACCOUNT2_PRIVATE_KEY");
        account3PrivateKey = vm.envUint("ACCOUNT3_PRIVATE_KEY");

        // Set account addresses
        owner = vm.addr(ownerPrivateKey);
        account1 = vm.addr(account1PrivateKey);
        account2 = vm.addr(account2PrivateKey);
        account3 = vm.addr(account3PrivateKey);

        // Load contract addresses from env
        bettingContract = BettingContract(vm.envAddress("BETTING_CONTRACT_ADDRESS"));
        usdcToken = IERC20(vm.envAddress("USDC_ADDRESS"));
        pointsToken = PointsToken(vm.envAddress("POINTS_TOKEN_ADDRESS"));

        // Check if we should skip owner verification
        bool skipOwnerVerification = false;
        try vm.envBool("SKIP_OWNER_VERIFICATION") returns (bool skip) {
            skipOwnerVerification = skip;
        } catch {
            // Default to false if not set
        }

        if (!skipOwnerVerification) {
            console2.log("Verifying contract ownership...");
            verifyOwnership();
        } else {
            console2.log("Skipping owner verification. Proceeding with script...");
        }
    }

    function verifyOwnership() internal {
        console2.log("calling owner() on bettingContract: %s", address(bettingContract));
        try bettingContract.owner() returns (address bettingContractOwner) {
            console2.log("owner() on bettingContract returned: %s", bettingContractOwner);
            if (owner != bettingContractOwner) {
                console2.log("ERROR: Owner address does not match BettingContract owner!");
                console2.log("Owner from private key: %s", owner);
                console2.log("BettingContract owner: %s", bettingContractOwner);
                revert("Owner address does not match BettingContract owner");
            }
            console2.log("BettingContract owner verification successful!");
        } catch {
            console2.log("WARNING: Could not verify BettingContract owner. Contract may not have owner() function.");
        }

        try pointsToken.owner() returns (address pointsTokenOwner) {
            if (owner != pointsTokenOwner) {
                console2.log("ERROR: Owner address does not match PointsToken owner!");
                console2.log("Owner from private key: %s", owner);
                console2.log("PointsToken owner: %s", pointsTokenOwner);
                revert("Owner address does not match PointsToken owner");
            }
            console2.log("PointsToken owner verification successful!");
        } catch {
            console2.log("WARNING: Could not verify PointsToken owner. Contract may not have owner() function.");
        }

        console2.log("Owner verification completed. Using address: %s", owner);
    }

    function run() public {
        setUp();

        // 1. Mint 10k FREEDOM to each account
        mintPointsToAccounts();

        // 2. Create 3 pools
        createPools();

        // 3 & 4. Place bets with points and USDC
        placeBets();

        // 5. Wait for bets to close
        // waitForBetsToClose();
        console2.log("Waiting 5 seconds...");
        vm.sleep(5 seconds);

        // 6. Grade pools randomly
        gradePools();

        // 7. Withdraw earnings
        withdrawEarnings();

        console2.log("End-to-end test completed successfully");
    }

    function mintPointsToAccounts() internal {
        console2.log("Minting 10k FREEDOM to each account");

        vm.startBroadcast(ownerPrivateKey);

        // Assuming the contract owner has minting privileges
        pointsToken.mint(account1, POINTS_AMOUNT);
        pointsToken.mint(account2, POINTS_AMOUNT);
        pointsToken.mint(account3, POINTS_AMOUNT);

        vm.stopBroadcast();

        console2.log("Points minted to accounts");
        console2.log("Account 1 points balance: %d", pointsToken.balanceOf(account1) / 10 ** 6);
        console2.log("Account 2 points balance: %d", pointsToken.balanceOf(account2) / 10 ** 6);
        console2.log("Account 3 points balance: %d", pointsToken.balanceOf(account3) / 10 ** 6);
    }

    function createPools() internal {
        console2.log("Creating 3 betting pools");

        vm.startBroadcast(ownerPrivateKey);

        // Pool 1
        BettingContract.CreatePoolParams memory pool1Params = BettingContract.CreatePoolParams({
            question: "Will I PARDON MYSELF? The RADICAL LEFT is TERRIFIED of this!",
            options: ["YES", "NO"],
            betsCloseAt: uint40(block.timestamp + 1 hours), // Much longer close time
            closureCriteria: "This pool will close if Trump posts that he will pardon himself",
            closureInstructions: "Grade YES if Trump posts about pardoning himself, NO otherwise",
            originalTruthSocialPostId: "114197092205719557"
        });

        uint256 pool1Id = bettingContract.createPool(pool1Params);
        poolIds.push(pool1Id);
        console2.log("Created pool 1 with ID: %d", pool1Id);

        // Pool 2
        BettingContract.CreatePoolParams memory pool2Params = BettingContract.CreatePoolParams({
            question: "Will I FIRE THE FBI DIRECTOR on day one? The FBI has been WEAPONIZED against us!",
            options: ["YES", "NO"],
            betsCloseAt: uint40(block.timestamp + 1 hours), // Much longer close time
            closureCriteria: "This pool will close if Trump makes a statement about the FBI Director",
            closureInstructions: "Grade YES if Trump says he will fire the FBI Director, NO otherwise",
            originalTruthSocialPostId: "114200175082806882"
        });

        uint256 pool2Id = bettingContract.createPool(pool2Params);
        poolIds.push(pool2Id);
        console2.log("Created pool 2 with ID: %d", pool2Id);

        // Pool 3
        BettingContract.CreatePoolParams memory pool3Params = BettingContract.CreatePoolParams({
            question: "Will I WIN the debate against SLEEPY JOE? Everyone knows I won the last one BIGLY!",
            options: ["YES", "NO"],
            betsCloseAt: uint40(block.timestamp + 1 hours), // Much longer close time
            closureCriteria: "This pool will close after the presidential debate",
            closureInstructions: "Grade YES if Trump wins the debate, NO otherwise",
            originalTruthSocialPostId: "114200313009802638"
        });

        uint256 pool3Id = bettingContract.createPool(pool3Params);
        poolIds.push(pool3Id);
        console2.log("Created pool 3 with ID: %d", pool3Id);

        vm.stopBroadcast();
    }

    function placeBets() internal {
        console2.log("Placing bets with points and USDC");

        // Account 1 bets
        placeBetsForAccount(account1, account1PrivateKey);

        // Account 2 bets
        placeBetsForAccount(account2, account2PrivateKey);

        // Account 3 bets
        placeBetsForAccount(account3, account3PrivateKey);
    }

    function placeBetsForAccount(address account, uint256 privateKey) internal {
        // Get initial balances
        uint256 initialPointsBalance = pointsToken.balanceOf(account);
        uint256 initialUsdcBalance = usdcToken.balanceOf(account);

        console2.log("Placing bets for account: %s", account);
        console2.log("Initial points balance: %d", initialPointsBalance / 10 ** 6);
        console2.log("Initial USDC balance: %d", initialUsdcBalance / 10 ** 6);

        // Approve tokens first
        vm.startBroadcast(privateKey);
        pointsToken.approve(address(bettingContract), initialPointsBalance);
        usdcToken.approve(address(bettingContract), initialUsdcBalance);
        vm.stopBroadcast();

        // Place points bets (distribute across pools)
        uint256 pointsPerPool = initialPointsBalance / poolIds.length;

        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 poolId = poolIds[i];

            // Randomly choose option (0 or 1)
            uint256 option = uint256(keccak256(abi.encodePacked(block.timestamp, account, poolId))) % 2;

            // Place bet with points (using 90% of allocated points to avoid rounding issues)
            uint256 pointsAmount = (pointsPerPool * 9) / 10;
            console2.log("Placing bet with points amount: %d", pointsAmount);
            // Start a new broadcast for each points bet
            vm.startBroadcast(privateKey);
            uint256 betId =
                bettingContract.placeBet(poolId, option, pointsAmount, account, BettingContract.TokenType.POINTS);
            userBetIds[account].push(betId);
            vm.stopBroadcast();

            // Wait a moment to ensure transaction is sent
            vm.sleep(2 seconds);
        }

        // Place USDC bets (1-5 USD per pool)
        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 poolId = poolIds[i];

            // Randomly choose option (0 or 1)
            uint256 option = uint256(keccak256(abi.encodePacked(block.timestamp, account, poolId, "usdc"))) % 2;

            // Random USDC amount between 1-5 USDC (assuming 6 decimals)
            uint256 usdcAmount = (1 + (uint256(keccak256(abi.encodePacked(block.timestamp, account, i))) % 5)) * 10 ** 6;
            console2.log("Placing bet with USDC amount: %d", usdcAmount);
            // Make sure we don't exceed balance
            if (usdcAmount <= usdcToken.balanceOf(account)) {
                // Start a new broadcast for each USDC bet
                vm.startBroadcast(privateKey);
                uint256 betId =
                    bettingContract.placeBet(poolId, option, usdcAmount, account, BettingContract.TokenType.USDC);
                userBetIds[account].push(betId);
                vm.stopBroadcast();

                // Wait a moment to ensure transaction is sent
                vm.sleep(2 seconds);
            }
        }

        // Log remaining balances
        console2.log("Remaining points: %d", pointsToken.balanceOf(account) / 10 ** 6);
        console2.log("Remaining USDC: %d", usdcToken.balanceOf(account) / 10 ** 6);
    }

    function waitForBetsToClose() internal {
        console2.log("Waiting for betting periods to close...");

        // Get the latest closing time from all pools
        uint40 latestCloseAt = 0;
        for (uint256 i = 0; i < poolIds.length; i++) {
            (,, uint40 betsCloseAt,,,,,,,) = bettingContract.pools(poolIds[i]);
            if (betsCloseAt > latestCloseAt) {
                latestCloseAt = betsCloseAt;
            }
        }

        // Calculate how long to wait (add 5 seconds buffer)
        uint256 currentTime = block.timestamp;
        if (latestCloseAt > currentTime) {
            uint256 waitTime = latestCloseAt - currentTime + 5;
            console2.log("Waiting %d seconds for all pools to close...", waitTime);
            vm.sleep(waitTime * 1 seconds);
        } else {
            console2.log("All betting pools are already closed");
        }

        // Verify all pools are now closed
        bool allClosed = true;
        for (uint256 i = 0; i < poolIds.length; i++) {
            (,, uint40 betsCloseAt,,,,,,,) = bettingContract.pools(poolIds[i]);
            if (block.timestamp <= betsCloseAt) {
                console2.log("Pool %d is still open!", poolIds[i]);
                allClosed = false;
            }
        }

        if (allClosed) {
            console2.log("All betting pools are now closed");
        } else {
            console2.log("WARNING: Not all pools have closed yet");
        }
    }

    function gradePools() internal {
        console2.log("Grading pools with random outcomes");

        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 poolId = poolIds[i];
            // Randomly choose outcome (0 or 1), no draw
            uint256 outcome = uint256(keccak256(abi.encodePacked(block.timestamp, poolId))) % 2;

            vm.startBroadcast(ownerPrivateKey);
            bettingContract.gradeBet(poolId, outcome);
            vm.stopBroadcast();

            // Wait a moment to ensure transaction is sent
            vm.sleep(2 seconds);

            string memory outcomeStr;
            if (outcome == 0) outcomeStr = "Option 0 (YES)";
            else if (outcome == 1) outcomeStr = "Option 1 (NO)";
            else outcomeStr = "Draw";

            console2.log("Graded pool: %d with outcome: %s", poolId, outcomeStr);
        }
    }

    function withdrawEarnings() internal {
        console2.log("Withdrawing earnings for all accounts");

        // Account 1 withdrawals
        withdrawEarningsForAccount(account1, account1PrivateKey);

        // Account 2 withdrawals
        withdrawEarningsForAccount(account2, account2PrivateKey);

        // Account 3 withdrawals
        withdrawEarningsForAccount(account3, account3PrivateKey);
    }

    function withdrawEarningsForAccount(address account, uint256 privateKey) internal {
        console2.log("Withdrawing earnings for account: %s", account);
        console2.log("Initial points balance: %d", pointsToken.balanceOf(account) / 10 ** 6);
        console2.log("Initial USDC balance: %d", usdcToken.balanceOf(account) / 10 ** 6);

        uint256[] memory betIds = userBetIds[account];

        // Use the account's private key to claim payouts
        vm.startBroadcast(privateKey);
        // First claim payouts to update user balances
        bettingContract.claimPayouts(betIds);
        console2.log("Claimed payouts for all bets");
        vm.stopBroadcast();

        // Check the user's balance in the contract for each token type
        uint256 usdcBalance = bettingContract.userBalances(account, BettingContract.TokenType.USDC);
        uint256 pointsBalance = bettingContract.userBalances(account, BettingContract.TokenType.POINTS);

        console2.log("User USDC balance in contract: %d", usdcBalance);
        console2.log("User POINTS balance in contract: %d", pointsBalance);

        // Check contract's actual token balances
        console2.log("Contract's actual USDC balance: %d", usdcToken.balanceOf(address(bettingContract)));
        console2.log("Contract's actual POINTS balance: %d", pointsToken.balanceOf(address(bettingContract)));

        // Withdraw using the account's private key
        if (usdcBalance > 0) {
            vm.startBroadcast(privateKey);
            try bettingContract.withdraw(BettingContract.TokenType.USDC, usdcBalance) {
                console2.log("Successfully withdrew USDC balance: %d", usdcBalance);
            } catch (bytes memory reason) {
                console2.log("Failed to withdraw USDC balance: %s", string(reason));
            }
            vm.stopBroadcast();

            // Wait a moment to ensure transaction is sent
            vm.sleep(2 seconds);
        }

        if (pointsBalance > 0) {
            vm.startBroadcast(privateKey);
            try bettingContract.withdraw(BettingContract.TokenType.POINTS, pointsBalance) {
                console2.log("Successfully withdrew POINTS balance: %d", pointsBalance / 10 ** 6);
            } catch (bytes memory reason) {
                console2.log("Failed to withdraw POINTS balance: %s", string(reason));
            }
            vm.stopBroadcast();

            // Wait a moment to ensure transaction is sent
            vm.sleep(2 seconds);
        }

        console2.log("Final points balance: %d", pointsToken.balanceOf(account) / 10 ** 6);
        console2.log("Final USDC balance: %d", usdcToken.balanceOf(account) / 10 ** 6);
    }
}
