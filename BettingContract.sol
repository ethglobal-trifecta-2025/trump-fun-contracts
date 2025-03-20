// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract BettingContract is Ownable {
    // Enums
    enum PoolStatus {
        NONE,
        PENDING,
        GRADED,
        REGRADED // Disputed (unused for now)

    }

    enum TokenType {
        USDC,
        POINTS
    }

    // Structs
    struct Pool {
        uint256 id; // Incremental id
        string question; // Bet question
        string[2] options; // Bet options
        uint40 betsCloseAt; // Time at which no more bets can be placed
        uint40 decisionDate; // UNUSED
        uint256[2] betTotals; // Total amount of money bet on each option
        uint256[] betIds; // Array of ids for user bets
        mapping(address => Bet[2]) betsByUser; // Mapping from user address to their bets. Bets for option
        uint256 winningOption; // Option that won the bet (0 or 1) (only matters if status is GRADED)
        PoolStatus status; // Status of the bet
        bool isDraw; // Indicates if the bet is a push (no winner and betters are refunded)
        uint256 createdAt; // Time at which the bet was created
        string imageUrl; // UNUSED
        string category; // UNUSED
        string creatorName; // Username of Telegram user who created the bet
        string creatorId; // Telegram id of user who created the bet
        string closureCriteria; // Criteria for WHEN a bet should be graded
        string closureInstructions; // Instructions for HOW to decide which option won
        string twitterPostId; // Twitter post id of the bet
    }

    struct Bet {
        uint256 id; // Incremental id
        address owner; // Address of user who made the bet
        uint256 option; // Option that the user bet on (0 or 1)
        uint256 amount; // Amount of tokens bet
        uint256 poolId; // Id of the pool the bet belongs to
        uint256 createdAt; // Time at which the bet was initially created
        uint256 updatedAt; // Time which bet was updated (ie: if a user added more money to their bet)
        bool isPayedOut; // Whether the bet has been paid out by Chainlink Automation
        TokenType tokenType; // Type of token used for the bet
    }

    struct CreatePoolParams {
        string question;
        string[2] options;
        uint40 betsCloseAt;
        uint40 decisionDate;
        string imageUrl;
        string category;
        string creatorName;
        string creatorId;
        string closureCriteria;
        string closureInstructions;
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
    mapping(address user => mapping(TokenType => uint256)) public userBalances;

    // Custom Errors
    error BetsCloseTimeInPast();
    error BetsCloseAfterDecision();
    error PoolNotOpen();
    error PoolDoesntExist();
    error BettingPeriodClosed();
    error InvalidOptionIndex();
    error BetAlreadyExists();
    error TokenTransferFailed();
    error NoBetToCancel();
    error TokenRefundFailed();
    error DecisionDateNotReached();
    error PoolAlreadyClosed();
    error ZeroAmount();
    error InsufficientBalance();
    error BettingPeriodNotClosed();
    error PoolNotGraded();
    error GradingError();
    error BetAlreadyPaidOut();
    error NotBetOwner();
    error InsufficientWithdrawBalance();

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
    event TwitterPostIdSet(uint256 indexed poolId, string twitterPostId);
    event PayoutClaimed(
        uint256 indexed betId, uint256 indexed poolId, address indexed user, uint256 amount, TokenType tokenType
    );
    event Withdrawal(address indexed user, uint256 amount, TokenType tokenType);

    constructor(address _usdc, address _pointsToken) Ownable(msg.sender) {
        usdc = ERC20(_usdc);
        pointsToken = ERC20(_pointsToken);
    }

    function createPool(CreatePoolParams calldata params) external onlyOwner returns (uint256 poolId) {
        if (params.betsCloseAt <= block.timestamp) revert BetsCloseTimeInPast();
        if (params.betsCloseAt > params.decisionDate) revert BetsCloseAfterDecision();

        poolId = nextPoolId++;

        Pool storage pool = pools[poolId];
        pool.id = poolId;
        pool.question = params.question;
        pool.options = params.options;
        pool.betsCloseAt = params.betsCloseAt;
        pool.decisionDate = params.decisionDate;
        pool.betTotals = [0, 0];
        pool.betIds = new uint256[](0);
        pool.winningOption = 0;
        pool.status = PoolStatus.PENDING;
        pool.isDraw = false;
        pool.createdAt = block.timestamp;
        pool.imageUrl = params.imageUrl;
        pool.category = params.category;
        pool.creatorName = params.creatorName;
        pool.creatorId = params.creatorId;
        pool.closureCriteria = params.closureCriteria;
        pool.closureInstructions = params.closureInstructions;

        emit PoolCreated(poolId, params);
    }

    function setTwitterPostId(uint256 poolId, string calldata twitterPostId) external onlyOwner {
        if (pools[poolId].status == PoolStatus.NONE) revert PoolDoesntExist();
        pools[poolId].twitterPostId = twitterPostId;
        emit TwitterPostIdSet(poolId, twitterPostId);
    }

    function placeBet(uint256 poolId, uint256 optionIndex, uint256 amount, address bettor, TokenType tokenType)
        external
        returns (uint256 betId)
    {
        if (block.timestamp > pools[poolId].betsCloseAt) revert BettingPeriodClosed();
        if (pools[poolId].status != PoolStatus.PENDING) revert PoolNotOpen();
        if (optionIndex >= 2) revert InvalidOptionIndex();
        if (amount <= 0) revert ZeroAmount();

        ERC20 token = tokenType == TokenType.USDC ? usdc : pointsToken;
        if (token.balanceOf(bettor) < amount) revert InsufficientBalance();

        bool success = token.transferFrom(bettor, address(this), amount);
        if (!success) revert TokenTransferFailed();

        betId = pools[poolId].betsByUser[bettor][optionIndex].id;
        if (betId == 0) {
            // User has not bet on this option before
            betId = nextBetId++;
            Bet memory newBet = Bet({
                id: betId,
                owner: bettor,
                option: optionIndex,
                amount: amount,
                poolId: poolId,
                createdAt: block.timestamp,
                updatedAt: block.timestamp,
                isPayedOut: false,
                tokenType: tokenType
            });
            bets[betId] = newBet;
            pools[poolId].betIds.push(betId);
            userBets[bettor].push(betId);
            pools[poolId].betsByUser[bettor][optionIndex] = newBet;
        } else {
            Bet storage existingBet = pools[poolId].betsByUser[bettor][optionIndex];
            existingBet.amount += amount;
            existingBet.updatedAt = block.timestamp;
            bets[betId].amount += amount;
            bets[betId].updatedAt = block.timestamp;

            // Ensure token type is consistent for the same bet
            if (bets[betId].tokenType != tokenType) revert("Cannot mix token types for the same bet");
        }
        pools[poolId].betTotals[optionIndex] += amount;

        emit BetPlaced(betId, poolId, bettor, optionIndex, amount, tokenType);
    }

    function gradeBet(uint256 poolId, uint256 responseOption) external onlyOwner {
        Pool storage pool = pools[poolId];

        if (pool.status != PoolStatus.PENDING) revert PoolNotOpen();
        if (block.timestamp < pool.betsCloseAt) revert BettingPeriodNotClosed();

        pool.status = PoolStatus.GRADED;

        if (responseOption == 0) {
            pool.winningOption = 0;
        } else if (responseOption == 1) {
            pool.winningOption = 1;
        } else if (responseOption == 2) {
            pool.isDraw = true;
        } else {
            revert GradingError();
        }

        emit PoolClosed(poolId, responseOption);
    }

    function claimPayouts(uint256[] calldata betIds) external {
        for (uint256 i = 0; i < betIds.length; i++) {
            uint256 betId = betIds[i];
            if (pools[bets[betId].poolId].status != PoolStatus.GRADED) continue;
            if (bets[betId].isPayedOut) continue;

            bets[betId].isPayedOut = true;
            uint256 poolId = bets[betId].poolId;
            TokenType tokenType = bets[betId].tokenType;
            ERC20 token = tokenType == TokenType.USDC ? usdc : pointsToken;

            // If it is a draw or there are no bets on one side or the other, refund the bet
            if (pools[poolId].isDraw || pools[poolId].betTotals[0] == 0 || pools[poolId].betTotals[1] == 0) {
                userBalances[bets[betId].owner][tokenType] += bets[betId].amount;
                continue;
            }

            uint256 losingOption = pools[poolId].winningOption == 0 ? 1 : 0;

            if (bets[betId].option == pools[poolId].winningOption) {
                uint256 winAmount = (bets[betId].amount * pools[poolId].betTotals[losingOption])
                    / pools[poolId].betTotals[pools[poolId].winningOption] + bets[betId].amount;
                uint256 fee = (winAmount * PAYOUT_FEE_BP) / 10000;
                uint256 payout = winAmount - fee;

                userBalances[bets[betId].owner][tokenType] += payout;
                userBalances[owner()][tokenType] += fee;

                emit PayoutClaimed(betId, poolId, bets[betId].owner, payout, tokenType);
            }
        }
    }

    function withdraw(uint256 amount, TokenType tokenType) external {
        if (amount == 0) revert ZeroAmount();
        if (userBalances[msg.sender][tokenType] < amount) revert InsufficientWithdrawBalance();

        userBalances[msg.sender][tokenType] -= amount;

        ERC20 token = tokenType == TokenType.USDC ? usdc : pointsToken;
        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TokenTransferFailed();

        emit Withdrawal(msg.sender, amount, tokenType);
    }
}
