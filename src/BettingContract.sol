// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
    }

    struct Bet {
        uint256 id; // Incremental id
        address owner; // Address of user who made the bet
        uint256 option; // Option that the user bet on (0 or 1)
        uint256 amount; // Amount of tokens bet
        uint256 poolId; // Id of the pool the bet belongs to
        uint256 createdAt; // Time at which the bet was initially created
        uint256 updatedAt; // Time which bet was updated (ie: if a user added more money to their bet)
        bool isPayedOut; // Whether the bet has been paid out
        bool isWithdrawn; // Whether the winnings have been withdrawn
        TokenType tokenType; // Type of token used for the bet
    }

    struct CreatePoolParams {
        string question;
        string[2] options;
        uint40 betsCloseAt;
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
    error PoolNotOpen();
    error PoolDoesntExist();
    error BettingPeriodClosed();
    error InvalidOptionIndex();
    error BetAlreadyExists();
    error TokenTransferFailed();
    error NoBetToCancel();
    error TokenRefundFailed();
    error PoolAlreadyClosed();
    error ZeroAmount();
    error InsufficientBalance();
    error BettingPeriodNotClosed();
    error PoolNotGraded();
    error GradingError();
    error BetAlreadyPaidOut();
    error NotBetOwner();
    error InsufficientWithdrawBalance();
    error TokenTypeMismatch();
    error BetNotPaidOut();
    error BetAlreadyWithdrawn();

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
    event Withdrawal(address indexed user, uint256 amount, TokenType tokenType);
    event BetWithdrawal(address indexed user, uint256 indexed betId, uint256 amount, TokenType tokenType);

    constructor(address _usdc, address _pointsToken) Ownable(msg.sender) {
        usdc = ERC20(_usdc);
        pointsToken = ERC20(_pointsToken);
    }

    function createPool(CreatePoolParams calldata params) external onlyOwner returns (uint256 poolId) {
        if (params.betsCloseAt <= block.timestamp) revert BetsCloseTimeInPast();

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

        emit PoolCreated(poolId, params);
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
                isPayedOut: false,
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

    // This function sends payouts to users proactively when a bet is graded
    // Unsure if it'll be used, but leaving here for now
    function claimPayouts(uint256[] calldata betIds) external {
        for (uint256 i = 0; i < betIds.length; i++) {
            uint256 betId = betIds[i];
            if (pools[bets[betId].poolId].status != PoolStatus.GRADED) continue;
            if (bets[betId].isPayedOut) continue;

            bets[betId].isPayedOut = true;
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

    function withdraw(uint256 betId) external {
        Bet storage bet = bets[betId];

        if (bet.owner != msg.sender) revert NotBetOwner();
        if (!bet.isPayedOut) revert BetNotPaidOut();
        if (bet.isWithdrawn) revert BetAlreadyWithdrawn();

        TokenType tokenType = bet.tokenType;
        uint256 poolId = bet.poolId;
        Pool storage pool = pools[poolId];

        uint256 amount = 0;

        // Calculate the payout amount based on the bet and pool state
        if (
            pool.isDraw || (tokenType == TokenType.USDC && (pool.usdcBetTotals[0] == 0 || pool.usdcBetTotals[1] == 0))
                || (tokenType == TokenType.POINTS && (pool.pointsBetTotals[0] == 0 || pool.pointsBetTotals[1] == 0))
        ) {
            // For draws or one-sided pools, just return the original bet amount
            amount = bet.amount;
        } else if (bet.option == pool.winningOption) {
            // Calculate winnings for correct predictions
            uint256[2] storage betTotals = tokenType == TokenType.USDC ? pool.usdcBetTotals : pool.pointsBetTotals;
            uint256 losingOption = pool.winningOption == 0 ? 1 : 0;
            uint256 winAmount = (bet.amount * betTotals[losingOption]) / betTotals[pool.winningOption] + bet.amount;
            uint256 fee = (winAmount * PAYOUT_FEE_BP) / 10000;
            amount = winAmount - fee;
        } else {
            // Losing bets get nothing
            revert ZeroAmount();
        }

        if (amount == 0) revert ZeroAmount();
        if (userBalances[msg.sender][tokenType] < amount) revert InsufficientWithdrawBalance();

        // Mark the bet as withdrawn
        bet.isWithdrawn = true;

        // Update the user's balance
        userBalances[msg.sender][tokenType] -= amount;

        // Transfer tokens
        ERC20 token = tokenType == TokenType.USDC ? usdc : pointsToken;
        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TokenTransferFailed();

        emit BetWithdrawal(msg.sender, betId, amount, tokenType);
    }
}
