// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {IPaymaster} from "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title TrumpFunPaymaster
 * @dev A paymaster that accepts payment in custom USDC or PointsToken
 * Each has a fixed 1:1 USD exchange rate
 */
contract TrumpFunPaymaster is IPaymaster, Ownable {
    // Constants
    uint256 internal constant SIG_VALIDATION_SUCCESS = 0;
    uint256 private constant PAYMASTER_DATA_OFFSET = 148;

    // Immutable variables
    IEntryPoint public immutable entryPoint;
    IERC20 public immutable pointsToken;
    IERC20 public immutable usdcToken;

    // Parameters
    uint256 public minDepositAmount; // Minimum deposit amount to accept transactions
    uint256 public gasPriceMarkup; // Gas price markup percentage (100 = 1%)
    uint256 public minBetAmount; // Minimum bet amount in USD (1 = 1 USD)

    // Events
    event UserOperationSponsored(
        address indexed user, address indexed token, uint256 actualTokenNeeded, uint256 actualGasCost
    );
    event DepositUpdated(uint256 newDepositAmount);
    event TokenRatioUpdated(address token, uint256 newRatio);
    event MinBetAmountUpdated(uint256 newMinBetAmount);

    enum TokenType {
        USDC,
        PointsToken
    }

    struct PaymasterData {
        TokenType tokenType;
        uint256 maxCost;
    }

    /**
     * @dev Constructor
     * @param _entryPoint EntryPoint contract
     * @param _pointsToken PointsToken contract address
     * @param _usdcToken USDC token contract address
     */
    constructor(IEntryPoint _entryPoint, IERC20 _pointsToken, IERC20 _usdcToken) Ownable(msg.sender) {
        entryPoint = _entryPoint;
        pointsToken = _pointsToken;
        usdcToken = _usdcToken;
        minDepositAmount = 0.01 ether; // Minimum deposit required
        gasPriceMarkup = 300; // 3% markup as default
        minBetAmount = 1 * 10 ** 6; // 1 USD (with 6 decimals)
    }

    /**
     * @dev Add a deposit for this paymaster in the EntryPoint
     */
    function deposit() public payable {
        entryPoint.depositTo{value: msg.value}(address(this));
        emit DepositUpdated(entryPoint.balanceOf(address(this)));
    }

    /**
     * @dev Withdraw deposit from EntryPoint to a specific address
     * @param withdrawAddress The address to send the funds to
     * @param amount The amount to withdraw
     */
    function withdrawTo(address payable withdrawAddress, uint256 amount) external onlyOwner {
        entryPoint.withdrawTo(withdrawAddress, amount);
        emit DepositUpdated(entryPoint.balanceOf(address(this)));
    }

    /**
     * @dev Set the markup percentage for gas cost conversion to tokens
     * @param _gasPriceMarkup New markup percentage (100 = 1%)
     */
    function setGasPriceMarkup(uint256 _gasPriceMarkup) external onlyOwner {
        gasPriceMarkup = _gasPriceMarkup;
    }

    /**
     * @dev Set minimum deposit amount required
     * @param _minDepositAmount New minimum amount
     */
    function setMinDepositAmount(uint256 _minDepositAmount) external onlyOwner {
        minDepositAmount = _minDepositAmount;
    }

    /**
     * @dev Set minimum bet amount (in USD)
     * @param _minBetAmount New minimum bet amount with 6 decimals (1000000 = 1 USD)
     */
    function setMinBetAmount(uint256 _minBetAmount) external onlyOwner {
        minBetAmount = _minBetAmount;
        emit MinBetAmountUpdated(_minBetAmount);
    }

    /**
     * @dev Check if a bet amount meets the minimum requirement
     * @param tokenAmount Amount of tokens to check (with 6 decimals)
     * @param tokenType Type of token (USDC or PointsToken)
     * @return True if the amount meets the minimum requirement
     */
    function isBetAmountValid(uint256 tokenAmount, TokenType tokenType) public view returns (bool) {
        // Both USDC and PointsToken have 1:1 USD ratio, so we can compare directly
        return tokenAmount >= minBetAmount;
    }

    /**
     * @dev Get current paymaster deposit in EntryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    /**
     * @dev Add stake for this paymaster to the EntryPoint
     * @param unstakeDelaySec The unstake delay for this paymaster
     */
    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        entryPoint.addStake{value: msg.value}(unstakeDelaySec);
    }

    /**
     * @dev Unlock stake in the EntryPoint
     */
    function unlockStake() external onlyOwner {
        entryPoint.unlockStake();
    }

    /**
     * @dev Withdraw stake from the EntryPoint
     * @param withdrawAddress Target to send to
     */
    function withdrawStake(address payable withdrawAddress) external onlyOwner {
        entryPoint.withdrawStake(withdrawAddress);
    }

    /**
     * @dev Convert Wei (ETH) amount to token amount (USDC or PointsToken)
     * Since both tokens have 6 decimals and 1:1 USD conversion, we use the same calculation
     * @param weiAmount The amount in wei
     * @return tokenAmount The amount in token units (6 decimals)
     */
    function convertEthToToken(uint256 weiAmount) public view returns (uint256 tokenAmount) {
        // Get ETH price in USD (fixed at 1 ETH = X USD for simplicity, ideally this would use a price oracle)
        uint256 ethPriceInUsd = getEthToUsdPrice();

        // Calculate token amount with markup
        // ETH has 18 decimals, ETH price has 8 decimals, tokens have 6 decimals
        // Need to convert to token decimals (6)
        return (weiAmount * ethPriceInUsd * (10000 + gasPriceMarkup)) / (10000 * 1e20);
    }

    /**
     * @dev Get the current ETH to USD price
     * In a production system, this would use a price oracle
     * @return price ETH price in USD with 8 decimals
     */
    function getEthToUsdPrice() public pure returns (uint256 price) {
        // Fixed price of 1 ETH = 3500 USD for testing (with 8 decimals)
        return 350000000000; // $3500 with 8 decimals
    }

    /**
     * @dev Extract token type and max cost from paymaster data
     * @param paymasterAndData The paymaster data from userOp
     * @return tokenType The selected token type
     * @return maxCost The maximum cost the user is willing to pay
     */
    function _parsePaymasterData(bytes calldata paymasterAndData)
        internal
        pure
        returns (TokenType tokenType, uint256 maxCost)
    {
        // Ensure that paymasterAndData has the correct length
        require(paymasterAndData.length >= PAYMASTER_DATA_OFFSET + 64, "TrumpFunPaymaster: Invalid data");

        // Extract tokenType and maxCost from the paymasterAndData
        bytes memory data = paymasterAndData[PAYMASTER_DATA_OFFSET:];
        (uint8 _tokenType, uint256 _maxCost) = abi.decode(data, (uint8, uint256));

        // Validate token type
        require(_tokenType <= uint8(TokenType.PointsToken), "TrumpFunPaymaster: Invalid token");

        return (TokenType(_tokenType), _maxCost);
    }

    /**
     * @dev Validate a user operation and check if the paymaster agrees to pay
     * @param userOp User operation
     * @param userOpHash Hash of the user operation
     * @param maxCost Maximum cost of the transaction
     * @return context Context for the postOp call
     * @return validationData Signature and time-range of this operation
     */
    function validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
        external
        returns (bytes memory context, uint256 validationData)
    {
        // Verify the call is from the EntryPoint
        require(msg.sender == address(entryPoint), "TrumpFunPaymaster: Sender not EntryPoint");

        // Verify paymaster has enough deposit
        require(getDeposit() >= minDepositAmount, "TrumpFunPaymaster: Not enough deposit");

        // Parse paymaster data
        (TokenType tokenType, uint256 maxTokenCost) = _parsePaymasterData(userOp.paymasterAndData);

        // Convert gas cost to token amount
        uint256 requiredTokenAmount = convertEthToToken(maxCost);

        // Check user has enough tokens of the chosen type and approved the paymaster
        if (tokenType == TokenType.USDC) {
            require(usdcToken.balanceOf(userOp.sender) >= requiredTokenAmount, "TrumpFunPaymaster: Not enough USDC");
            require(
                usdcToken.allowance(userOp.sender, address(this)) >= requiredTokenAmount,
                "TrumpFunPaymaster: Not enough USDC allowance"
            );
        } else {
            require(
                pointsToken.balanceOf(userOp.sender) >= requiredTokenAmount, "TrumpFunPaymaster: Not enough PointsToken"
            );
            require(
                pointsToken.allowance(userOp.sender, address(this)) >= requiredTokenAmount,
                "TrumpFunPaymaster: Not enough PointsToken allowance"
            );
        }

        // Verify user's specified maximum cost
        require(maxTokenCost >= requiredTokenAmount, "TrumpFunPaymaster: Max cost too low");

        // Pack the context for postOp
        bytes memory _context = abi.encode(userOp.sender, tokenType, requiredTokenAmount);

        // Return success and context
        return (_context, SIG_VALIDATION_SUCCESS);
    }

    /**
     * @dev Handle post-operation, including charging the user for gas fees
     * @param mode Post operation mode
     * @param context Context from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost used in the transaction
     * @param actualUserOpFeePerGas The gas price for this UserOp
     */
    function postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256 actualUserOpFeePerGas)
        external
    {
        // Verify the call is from the EntryPoint
        require(msg.sender == address(entryPoint), "TrumpFunPaymaster: Sender not EntryPoint");

        // Extract context data
        (address sender, TokenType tokenType, uint256 preChargeTokenAmount) =
            abi.decode(context, (address, TokenType, uint256));

        // Calculate actual token amount needed based on actual gas used
        uint256 actualTokenNeeded = convertEthToToken(actualGasCost);

        // We don't need to handle the postOpReverted case since we're not pre-charging

        // If operation succeeded or reverted, charge the user
        if (mode == PostOpMode.opSucceeded || mode == PostOpMode.opReverted) {
            // Transfer tokens from user to paymaster based on token type
            if (tokenType == TokenType.USDC) {
                // Charge the actual amount needed
                require(
                    usdcToken.transferFrom(sender, address(this), actualTokenNeeded),
                    "TrumpFunPaymaster: USDC transfer failed"
                );
                emit UserOperationSponsored(sender, address(usdcToken), actualTokenNeeded, actualGasCost);
            } else {
                // Charge the actual amount needed
                require(
                    pointsToken.transferFrom(sender, address(this), actualTokenNeeded),
                    "TrumpFunPaymaster: PointsToken transfer failed"
                );
                emit UserOperationSponsored(sender, address(pointsToken), actualTokenNeeded, actualGasCost);
            }
        }
    }
}
