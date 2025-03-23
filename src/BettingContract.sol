// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";

contract BettingContract is Ownable {
    enum PoolStatus {
        NONE,
        PENDING,
        GRADED,
        REGRADED // Disputed (leave here, but unused for now)

    }

    enum TokenType {
        USDC,
        POINTS
    }

    struct Pool {
        uint256 id; // Incremental id
        string question; // Bet question, "Will I WIN the case against the CORU"
        string[2] options; // Bet options, index 0 is the first option, index 1 is the second option, etc. Must align with indices in the other fields
        uint256[2] usdcBetTotals; // Total amount bet on each option for USDC [optionIndex]. Must align with options array
        uint256[2] pointsBetTotals; // Total amount bet on each option for POINTS [optionIndex]. Must align with options array
        uint40 betsCloseAt; // Time at which no more bets can be placed
        mapping(address => Bet[2]) usdcBetsByUser; // Mapping from user address to their USDC bets. Must align with options array
        mapping(address => Bet[2]) pointsBetsByUser; // Mapping from user address to their POINTS bets. Must align with options array
        uint256 winningOption; // Option that won the bet (0 or 1) (only matters if status is GRADED)
        PoolStatus status; // Status of the bet
        bool isDraw; // Indicates if the bet is a push (no winner and betters are refunded)
        uint256 createdAt; // Time at which the bet was created
        string closureCriteria; // Criteria for WHEN a bet should be graded
        string closureInstructions; // Instructions for HOW to decide which option won
        string originalTruthSocialPostId; // The ID of the original Truth Social post
        uint256[] betIds; // Array of all bet IDs in this pool
    }

    struct Bet {
        uint256 id; // Incremental id
        address owner; // Address of user who made the bet
        uint256 option; // Option that the user bet on (0 or 1)
        uint256 amount; // Amount of tokens bet
        uint256 poolId; // Id of the pool the bet belongs to
        uint256 createdAt; // Time at which the bet was initially created
        uint256 updatedAt; // Time which bet was updated (ie: if a user added more money to their bet)
        bool isWithdrawn; // Whether the bet has been paid out and winnings have been withdrawn
        TokenType tokenType; // Type of token used for the bet
    }

    struct CreatePoolParams {
        string question;
        string[2] options;
        uint40 betsCloseAt;
        string closureCriteria;
        string closureInstructions;
        string originalTruthSocialPostId;
    }

    uint256 public constant PAYOUT_FEE_BP = 90; // 0.9% fee for the payout

    // State
    ERC20 public usdc;
    ERC20 public pointsToken;

    uint256 public nextPoolId = 1;
    uint256 public nextBetId = 1;

    mapping(uint256 poolId => Pool pool) public pools;
    mapping(uint256 betId => Bet bet) public bets;
    mapping(address bettor => uint256[] betIds) public userBets;
    mapping(address user => mapping(TokenType tokenType => uint256 balance)) public userBalances;

    // Custom Errors
    error BetsCloseTimeInPast(uint40 providedTime, uint256 currentTime);
    error PoolNotOpen(uint256 poolId, PoolStatus currentStatus);
    error PoolDoesntExist(uint256 poolId);
    error BettingPeriodClosed(uint256 poolId, uint40 closedAt, uint256 currentTime);
    error InvalidOptionIndex(uint256 providedIndex, uint256 maxIndex);
    error BetAlreadyExists(uint256 betId, address bettor, uint256 poolId);
    error TokenTransferFailed(address token, address from, address to, uint256 amount);
    error NoBetToCancel(uint256 poolId, address bettor, uint256 optionIndex);
    error TokenRefundFailed(address token, address to, uint256 amount);
    error PoolAlreadyClosed(uint256 poolId, PoolStatus currentStatus);
    error ZeroAmount();
    error InsufficientBalance(address user, uint256 required, uint256 actual);
    error BettingPeriodNotClosed(uint256 poolId, uint40 closesAt, uint256 currentTime);
    error PoolNotGraded(uint256 poolId, PoolStatus currentStatus);
    error GradingError(uint256 poolId, uint256 invalidOption);
    error BetAlreadyPaidOut(uint256 betId);
    error NotBetOwner(uint256 betId, address caller, address owner);
    error InsufficientWithdrawBalance(address user, TokenType tokenType, uint256 requested, uint256 available);
    error TokenTypeMismatch(uint256 betId, TokenType expected, TokenType provided);
    error BetNotPaidOut(uint256 betId);
    error BetAlreadyWithdrawn(uint256 betId);

    // Events
    event PoolCreated(uint256 poolId, CreatePoolParams params);
    event PoolClosed(uint256 indexed poolId, uint256 selectedOption);
    event BetPlaced(
        uint256 indexed betId,
        uint256 indexed poolId,
        address indexed user,
        uint256 optionIndex,
        uint256 amount,
        TokenType tokenType
    );
    event PayoutClaimed(
        uint256 indexed betId, uint256 indexed poolId, address indexed user, uint256 amount, TokenType tokenType
    );
    event BetWithdrawal(address indexed user, uint256 indexed betId, uint256 amount, TokenType tokenType);
    event Withdrawal(address indexed user, uint256 amount, TokenType tokenType);

    constructor(address _usdc, address _pointsToken) Ownable(msg.sender) {
        usdc = ERC20(_usdc);
        pointsToken = ERC20(_pointsToken);
    }

    function createPool(CreatePoolParams calldata params) external onlyOwner returns (uint256 poolId) {
        console.log("Create pool block.timestamp", block.timestamp);
        if (params.betsCloseAt <= block.timestamp) revert BetsCloseTimeInPast(params.betsCloseAt, block.timestamp);

        poolId = nextPoolId++;

        Pool storage pool = pools[poolId];
        pool.id = poolId;
        pool.question = params.question;
        pool.options = params.options;
        pool.betsCloseAt = params.betsCloseAt;
        pool.usdcBetTotals = [0, 0];
        pool.pointsBetTotals = [0, 0];
        pool.winningOption = 0;
        pool.status = PoolStatus.PENDING;
        pool.isDraw = false;
        pool.createdAt = block.timestamp;
        pool.closureCriteria = params.closureCriteria;
        pool.closureInstructions = params.closureInstructions;
        pool.originalTruthSocialPostId = params.originalTruthSocialPostId;

        emit PoolCreated(poolId, params);
    }

    function placeBet(uint256 poolId, uint256 optionIndex, uint256 amount, address bettor, TokenType tokenType)
        external
        returns (uint256 betId)
    {
        if (block.timestamp > pools[poolId].betsCloseAt) {
            revert BettingPeriodClosed(poolId, pools[poolId].betsCloseAt, block.timestamp);
        }
        if (pools[poolId].status != PoolStatus.PENDING) revert PoolNotOpen(poolId, pools[poolId].status);
        if (optionIndex >= 2) revert InvalidOptionIndex(optionIndex, 1);
        if (amount <= 0) revert ZeroAmount();

        ERC20 token = tokenType == TokenType.USDC ? usdc : pointsToken;
        if (token.balanceOf(bettor) < amount) revert InsufficientBalance(bettor, amount, token.balanceOf(bettor));

        bool success = token.transferFrom(bettor, address(this), amount);
        if (!success) revert TokenTransferFailed(address(token), bettor, address(this), amount);

        // Get betId from the appropriate mapping based on token type
        betId = tokenType == TokenType.USDC
            ? pools[poolId].usdcBetsByUser[bettor][optionIndex].id
            : pools[poolId].pointsBetsByUser[bettor][optionIndex].id;

        if (betId == 0) {
            // User has not bet on this option before with this token type
            betId = nextBetId++;
            Bet memory newBet = Bet({
                id: betId,
                owner: bettor,
                option: optionIndex,
                amount: amount,
                poolId: poolId,
                createdAt: block.timestamp,
                updatedAt: block.timestamp,
                isWithdrawn: false,
                tokenType: tokenType
            });
            bets[betId] = newBet;
            userBets[bettor].push(betId);

            // Store bet in the appropriate mapping based on token type
            if (tokenType == TokenType.USDC) {
                pools[poolId].usdcBetsByUser[bettor][optionIndex] = newBet;
            } else {
                pools[poolId].pointsBetsByUser[bettor][optionIndex] = newBet;
            }

            // Track bet ID in the pool
            pools[poolId].betIds.push(betId);
        } else {
            // Get existing bet from the appropriate mapping based on token type
            Bet storage existingBet = tokenType == TokenType.USDC
                ? pools[poolId].usdcBetsByUser[bettor][optionIndex]
                : pools[poolId].pointsBetsByUser[bettor][optionIndex];

            existingBet.amount += amount;
            existingBet.updatedAt = block.timestamp;
            bets[betId].amount += amount;
            bets[betId].updatedAt = block.timestamp;
        }

        // Update the total amount bet for this token type and option
        if (tokenType == TokenType.USDC) {
            pools[poolId].usdcBetTotals[optionIndex] += amount;
        } else {
            pools[poolId].pointsBetTotals[optionIndex] += amount;
        }

        emit BetPlaced(betId, poolId, bettor, optionIndex, amount, tokenType);
    }

    function gradeBet(uint256 poolId, uint256 responseOption) external onlyOwner {
        Pool storage pool = pools[poolId];

        if (pool.status != PoolStatus.PENDING) revert PoolNotOpen(poolId, pool.status);
        //TODO Think about the below in more detail
        // It's possible for a bet to be graded mid-betting. Is that ideal? Absolutely not, but we're dealing with a stable genius here.
        // if (block.timestamp < pool.betsCloseAt) {
        // revert BettingPeriodNotClosed(poolId, pool.betsCloseAt, block.timestamp);
        // }

        pool.status = PoolStatus.GRADED;

        if (responseOption == 0) {
            pool.winningOption = 0;
        } else if (responseOption == 1) {
            pool.winningOption = 1;
        } else if (responseOption == 2) {
            pool.isDraw = true;
        } else {
            revert GradingError(poolId, responseOption);
        }

        emit PoolClosed(poolId, responseOption);

        // Create a memory copy of the bet IDs array to claim all bets in pool
        uint256[] memory betIdsToProcess = new uint256[](pool.betIds.length);
        for (uint256 i = 0; i < pool.betIds.length; i++) {
            betIdsToProcess[i] = pool.betIds[i];
        }
        claimPayouts(betIdsToProcess);
    }

    // This function sends payouts to users proactively when a bet is graded
    // Unsure if it'll be used, but leaving here for now
    function claimPayouts(uint256[] memory betIds) public {
        for (uint256 i = 0; i < betIds.length; i++) {
            uint256 betId = betIds[i];
            if (pools[bets[betId].poolId].status != PoolStatus.GRADED) continue;
            if (bets[betId].isWithdrawn) continue;

            bets[betId].isWithdrawn = true;
            uint256 poolId = bets[betId].poolId;
            TokenType tokenType = bets[betId].tokenType;

            // Get the appropriate betTotals based on token type
            uint256[2] storage betTotals =
                tokenType == TokenType.USDC ? pools[poolId].usdcBetTotals : pools[poolId].pointsBetTotals;

            // If it is a draw or there are no bets on one side or the other for this token type, refund the bet
            if (pools[poolId].isDraw || betTotals[0] == 0 || betTotals[1] == 0) {
                userBalances[bets[betId].owner][tokenType] += bets[betId].amount;
                continue;
            }

            uint256 losingOption = pools[poolId].winningOption == 0 ? 1 : 0;

            if (bets[betId].option == pools[poolId].winningOption) {
                uint256 winAmount = (bets[betId].amount * betTotals[losingOption])
                    / betTotals[pools[poolId].winningOption] + bets[betId].amount;
                uint256 fee = (winAmount * PAYOUT_FEE_BP) / 10000;
                uint256 payout = winAmount - fee;

                userBalances[bets[betId].owner][tokenType] += payout;
                userBalances[owner()][tokenType] += fee;

                emit PayoutClaimed(betId, poolId, bets[betId].owner, payout, tokenType);
            }
        }
    }

    function withdraw(TokenType tokenType, uint256 amount) public {
        if (amount == 0) revert ZeroAmount();

        // Check user balance
        uint256 userBalance = userBalances[msg.sender][tokenType];
        if (userBalance < amount) {
            revert InsufficientWithdrawBalance(msg.sender, tokenType, amount, userBalance);
        }

        // Select the token
        ERC20 token = tokenType == TokenType.USDC ? usdc : pointsToken;

        // Check contract's token balance
        uint256 contractBalance = token.balanceOf(address(this));
        if (contractBalance < amount) {
            revert InsufficientBalance(address(this), amount, contractBalance);
        }

        // Update the user's balance
        userBalances[msg.sender][tokenType] -= amount;

        // Transfer tokens
        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TokenTransferFailed(address(token), address(this), msg.sender, amount);

        emit Withdrawal(msg.sender, amount, tokenType);
    }

    function withdrawAll(TokenType tokenType) public {
        uint256 balance = userBalances[msg.sender][tokenType];
        if (balance > 0) {
            withdraw(tokenType, balance);
        }
    }
}
