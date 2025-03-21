// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

// Interfaces for existing contracts
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 amount) external;
}

interface IBettingContract {
    enum TokenType {
        USDC,
        POINTS
    }

    struct CreatePoolParams {
        string question;
        string[2] options;
        uint40 betsCloseAt;
        string closureCriteria;
        string closureInstructions;
        string originalTruthSocialPostId;
    }

    function createPool(CreatePoolParams calldata params) external returns (uint256 poolId);
    function placeBet(uint256 poolId, uint256 optionIndex, uint256 amount, address bettor, TokenType tokenType)
        external
        returns (uint256 betId);
    function gradeBet(uint256 poolId, uint256 responseOption) external;
    function withdraw(uint256 betId) external;
}

contract EndToEndTest is Script {
    // Contracts
    IBettingContract public bettingContract;
    IERC20 public usdcToken;
    IERC20 public pointsToken;

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
    uint256 public constant POINTS_AMOUNT = 10_000 * 10 ** 18; // 10k FREEDOM (assuming 18 decimals)

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
        bettingContract = IBettingContract(vm.envAddress("BETTING_CONTRACT_ADDRESS"));
        usdcToken = IERC20(vm.envAddress("USDC_ADDRESS"));
        pointsToken = IERC20(vm.envAddress("POINTS_TOKEN_ADDRESS"));
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
        waitForBetsToClose();

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
        console2.log("Account 1 points balance:", pointsToken.balanceOf(account1) / 10 ** 18);
        console2.log("Account 2 points balance:", pointsToken.balanceOf(account2) / 10 ** 18);
        console2.log("Account 3 points balance:", pointsToken.balanceOf(account3) / 10 ** 18);
    }

    function createPools() internal {
        console2.log("Creating 3 betting pools");

        vm.startBroadcast(ownerPrivateKey);

        // Pool 1
        IBettingContract.CreatePoolParams memory pool1Params = IBettingContract.CreatePoolParams({
            question: "Will I PARDON MYSELF? The RADICAL LEFT is TERRIFIED of this!",
            options: ["YES", "NO"],
            betsCloseAt: uint40(block.timestamp + 30), // 30 seconds from now
            closureCriteria: "This pool will close if Trump posts that he will pardon himself",
            closureInstructions: "Grade YES if Trump posts about pardoning himself, NO otherwise",
            originalTruthSocialPostId: "pool1"
        });

        uint256 pool1Id = bettingContract.createPool(pool1Params);
        poolIds.push(pool1Id);
        console2.log("Created pool 1 with ID:", pool1Id);

        // Pool 2
        IBettingContract.CreatePoolParams memory pool2Params = IBettingContract.CreatePoolParams({
            question: "Will I FIRE THE FBI DIRECTOR on day one? The FBI has been WEAPONIZED against us!",
            options: ["YES", "NO"],
            betsCloseAt: uint40(block.timestamp + 30), // 30 seconds from now
            closureCriteria: "This pool will close if Trump makes a statement about the FBI Director",
            closureInstructions: "Grade YES if Trump says he will fire the FBI Director, NO otherwise",
            originalTruthSocialPostId: "pool2"
        });

        uint256 pool2Id = bettingContract.createPool(pool2Params);
        poolIds.push(pool2Id);
        console2.log("Created pool 2 with ID:", pool2Id);

        // Pool 3
        IBettingContract.CreatePoolParams memory pool3Params = IBettingContract.CreatePoolParams({
            question: "Will I WIN the debate against SLEEPY JOE? Everyone knows I won the last one BIGLY!",
            options: ["YES", "NO"],
            betsCloseAt: uint40(block.timestamp + 30), // 30 seconds from now
            closureCriteria: "This pool will close after the presidential debate",
            closureInstructions: "Grade YES if Trump wins the debate, NO otherwise",
            originalTruthSocialPostId: "pool3"
        });

        uint256 pool3Id = bettingContract.createPool(pool3Params);
        poolIds.push(pool3Id);
        console2.log("Created pool 3 with ID:", pool3Id);

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

        console2.log("Placing bets for account:", account);
        console2.log("Initial points balance:", initialPointsBalance / 10 ** 18);
        console2.log("Initial USDC balance:", initialUsdcBalance / 10 ** 6, "USDC");

        vm.startBroadcast(privateKey);

        // Approve tokens for betting contract
        pointsToken.approve(address(bettingContract), initialPointsBalance);
        usdcToken.approve(address(bettingContract), initialUsdcBalance);

        // Place points bets (distribute across pools)
        uint256 pointsPerPool = initialPointsBalance / poolIds.length;

        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 poolId = poolIds[i];

            // Randomly choose option (0 or 1)
            uint256 option = uint256(keccak256(abi.encodePacked(block.timestamp, account, poolId))) % 2;

            // Place bet with points (using 90% of allocated points to avoid rounding issues)
            uint256 pointsAmount = (pointsPerPool * 9) / 10;
            uint256 betId =
                bettingContract.placeBet(poolId, option, pointsAmount, account, IBettingContract.TokenType.POINTS);
            userBetIds[account].push(betId);

            console2.log(
                "Placed points bet:", betId, "on pool:", poolId, "option:", option, "amount:", pointsAmount / 10 ** 18
            );
        }

        // Place USDC bets (1-5 USD per pool)
        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 poolId = poolIds[i];

            // Randomly choose option (0 or 1)
            uint256 option = uint256(keccak256(abi.encodePacked(block.timestamp, account, poolId, "usdc"))) % 2;

            // Random USDC amount between 1-5 USDC (assuming 6 decimals)
            uint256 usdcAmount = (1 + (uint256(keccak256(abi.encodePacked(block.timestamp, account, i))) % 5)) * 10 ** 6;

            // Make sure we don't exceed balance
            if (usdcAmount <= usdcToken.balanceOf(account)) {
                uint256 betId =
                    bettingContract.placeBet(poolId, option, usdcAmount, account, IBettingContract.TokenType.USDC);
                userBetIds[account].push(betId);

                console2.log(
                    "Placed USDC bet:",
                    betId,
                    "on pool:",
                    poolId,
                    "option:",
                    option,
                    "amount:",
                    usdcAmount / 10 ** 6,
                    "USDC"
                );
            }
        }

        vm.stopBroadcast();

        // Log remaining balances
        console2.log("Remaining points:", pointsToken.balanceOf(account) / 10 ** 18);
        console2.log("Remaining USDC:", usdcToken.balanceOf(account) / 10 ** 6, "USDC");
    }

    function waitForBetsToClose() internal {
        console2.log("Waiting for bets to close (30 seconds)...");

        // Here we can use vm.warp in a test, but for a script that's actually
        // executing transactions, we need to actually wait
        vm.sleep(31 seconds);

        console2.log("Bets are now closed");
    }

    function gradePools() internal {
        console2.log("Grading pools with random outcomes");

        vm.startBroadcast(ownerPrivateKey);

        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 poolId = poolIds[i];

            // Randomly choose outcome (0, 1, or 2 for draw)
            uint256 outcome = uint256(keccak256(abi.encodePacked(block.timestamp, poolId))) % 3;

            bettingContract.gradeBet(poolId, outcome);

            string memory outcomeStr;
            if (outcome == 0) outcomeStr = "Option 0 (YES)";
            else if (outcome == 1) outcomeStr = "Option 1 (NO)";
            else outcomeStr = "Draw";

            console2.log("Graded pool:", poolId, "with outcome:", outcomeStr);
        }

        vm.stopBroadcast();
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
        console2.log("Withdrawing earnings for account:", account);
        console2.log("Initial points balance:", pointsToken.balanceOf(account) / 10 ** 18);
        console2.log("Initial USDC balance:", usdcToken.balanceOf(account) / 10 ** 6, "USDC");

        uint256[] memory betIds = userBetIds[account];

        vm.startBroadcast(privateKey);

        for (uint256 i = 0; i < betIds.length; i++) {
            try bettingContract.withdraw(betIds[i]) {
                console2.log("Successfully withdrew earnings for bet ID:", betIds[i]);
            } catch (bytes memory reason) {
                console2.log("Failed to withdraw earnings for bet ID:", betIds[i]);
                // We continue the loop even if one withdrawal fails
            }
        }

        vm.stopBroadcast();

        console2.log("Final points balance:", pointsToken.balanceOf(account) / 10 ** 18);
        console2.log("Final USDC balance:", usdcToken.balanceOf(account) / 10 ** 6, "USDC");
    }
}
