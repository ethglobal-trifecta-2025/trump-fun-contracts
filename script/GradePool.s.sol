// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
//import {console2} from "forge-std/console.sol";
import "forge-std/console2.sol";

import {BettingContract} from "../src/BettingContract.sol";
import {PointsToken} from "../src/PointsToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GradePoolScript is Script {
    // Define the parameters to be passed from the command line
    uint256 public poolId;
    uint256 public responseOption;
    uint256 public ownerPrivateKey;
    uint256 public account1PrivateKey;
    uint256 public account2PrivateKey;
    uint256 public account3PrivateKey;
    BettingContract public bettingContract;
    PointsToken public pointsToken;
    IERC20 public usdcToken;
    address public constant BETTING_CONTRACT = 0x2E180501D3D68241dd0318c68fD9BE0AF1D519a1;
    
    // Account addresses
    address public account1 =0x4E5dC9dF946500b07E9c66e4DD29bf9CD062002B;
    address public account2 =0x67bFd0B42F5f39710B4E90301289F81Eab6315dA;
    address public account3 =0x12BE474D127757d0a6a36631294F8FfBCdeF44F8;

    mapping(address => uint256[]) public userBetIds;
    uint256 public constant POINTS_AMOUNT = 10000;
    uint256[] public poolIds;

    function setUp() public {
        // Get owner's private key
        ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Load private keys from env
        account1PrivateKey = vm.envUint("ACCOUNT1_PRIVATE_KEY");
        account2PrivateKey = vm.envUint("ACCOUNT2_PRIVATE_KEY");
        account3PrivateKey = vm.envUint("ACCOUNT3_PRIVATE_KEY");

        // Initialize contracts
        bettingContract = BettingContract(BETTING_CONTRACT);
        pointsToken = PointsToken(vm.envAddress("POINTS_TOKEN_ADDRESS"));
        usdcToken = IERC20(vm.envAddress("USDC_ADDRESS"));
        
        // Log current state
        console2.log("Contract address:", address(bettingContract));
        console2.log("Next pool ID:", bettingContract.nextPoolId());
    }
    

    function run() public {
         setUp();

        // 1. Mint 10k FREEDOM to each account
        mintPointsToAccounts();
createPools();
        // 3 & 4. Place bets with points and USDC
        placeBets();
        // Get pool ID and response option from environment
        poolId = 192; // All accounts will bet in pool 192
        responseOption = vm.envUint("RESPONSE_OPTION");

        // Log grading information
        console2.log("Grading pool", poolId, "with response option", responseOption);

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
        console2.log("Pool ID:", id);
        console2.log("Question:", question);
        console2.log("Pool Status:", uint8(status)); // 0 = NONE, 1 = PENDING, 2 = GRADED
        console2.log("Bets Close At:", betsCloseAt);
        console2.log("Current Time:", block.timestamp);

        // Check if pool exists and is in correct state
        require(id > 0, "Pool does not exist");
        require(status == BettingContract.PoolStatus.PENDING, "Pool is not in PENDING status");
        require(responseOption <= 2, "Invalid response option (must be 0, 1, or 2)");

        // Start broadcasting transactions
        vm.startBroadcast(ownerPrivateKey);

        // Grade the pool
        bettingContract.gradeBet(poolId, responseOption);
        console2.log("Successfully graded pool", poolId, "with response option", responseOption);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Withdraw earnings for all accounts
        withdrawEarnings();
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

        // All accounts bet in pool 192
        placeBetsForAccount(account1, account1PrivateKey);
        placeBetsForAccount(account2, account2PrivateKey);
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

        // Check if poolIds is populated
        require(poolIds.length > 0, "No pools available for betting");

        // Place points bets (distribute across pools)
        uint256 pointsPerPool = initialPointsBalance / poolIds.length;

        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 currentPoolId = poolIds[i];

            // Randomly choose option (0 or 1)
            uint256 option = uint256(keccak256(abi.encodePacked(block.timestamp, account, currentPoolId))) % 2;

            // Place bet with points (using 90% of allocated points to avoid rounding issues)
            uint256 pointsAmount = (pointsPerPool * 9) / 10;
            console2.log("Placing bet with points amount: %d", pointsAmount);
            // Start a new broadcast for each points bet
            vm.startBroadcast(privateKey);
            uint256 betId =
                bettingContract.placeBet(currentPoolId, option, pointsAmount, account, BettingContract.TokenType.POINTS);
            userBetIds[account].push(betId);
            vm.stopBroadcast();

            // Wait a moment to ensure transaction is sent
            vm.sleep(2 seconds);
        }

        // Place USDC bets (1-5 USD per pool)
        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 currentPoolId = poolIds[i];

            // Randomly choose option (0 or 1)
            uint256 option = uint256(keccak256(abi.encodePacked(block.timestamp, account, currentPoolId, "usdc"))) % 2;

            // Random USDC amount between 1-5 USDC (assuming 6 decimals)
            uint256 usdcAmount = (1 + (uint256(keccak256(abi.encodePacked(block.timestamp, account, i))) % 5)) * 10 ** 6;
            console2.log("Placing bet with USDC amount: %d", usdcAmount);
            // Make sure we don't exceed balance
            if (usdcAmount <= usdcToken.balanceOf(account)) {
                // Start a new broadcast for each USDC bet
                vm.startBroadcast(privateKey);
                uint256 betId =
                    bettingContract.placeBet(currentPoolId, option, usdcAmount, account, BettingContract.TokenType.USDC);
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

     function withdrawEarnings() internal {
        console2.log("Withdrawing earnings for all accounts");

        // Withdraw for each account
        withdrawEarningsForAccount(account1, account1PrivateKey);
        withdrawEarningsForAccount(account2, account2PrivateKey);
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
