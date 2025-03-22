// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/TrumpFunPaymaster.sol";
import "../src/PointsToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {console} from "forge-std/console.sol";

// Mock USDC token for testing
contract MockUSDC is ERC20 {
    uint8 private _decimals;

    constructor() ERC20("USD Coin", "USDC") {
        _decimals = 6;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock EntryPoint contract for testing - made concrete
contract MockEntryPoint is IEntryPoint {
    mapping(address => uint256) public balanceOf;

    function depositTo(address account) external payable {
        balanceOf[account] += msg.value;
    }

    function withdrawTo(address payable to, uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        (bool success,) = to.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function addStake(uint32 unstakeDelaySec) external payable {
        // Simplified implementation for testing
    }

    function unlockStake() external {
        // Simplified implementation for testing
    }

    function withdrawStake(address payable withdrawAddress) external {
        // Simplified implementation for testing
    }

    // Required functions that are not used in our test but needed to implement the interface
    function handleOps(PackedUserOperation[] calldata, address payable) external {}
    function handleAggregatedOps(UserOpsPerAggregator[] calldata, address payable) external {}

    function getNonce(address, uint192) external view returns (uint256) {
        return 0;
    }

    function simulateHandleOp(PackedUserOperation calldata, address, bytes calldata)
        external
        pure
        returns (uint256, uint256)
    {
        return (0, 0);
    }

    function simulateValidation(PackedUserOperation calldata) external pure {}

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }

    function getUserOpHash(PackedUserOperation calldata) external pure returns (bytes32) {
        return bytes32(0);
    }

    function incrementNonce(uint192) external {}

    // Additional missing implementations
    function delegateAndRevert(address target, bytes calldata data) external {
        // Empty implementation for testing purposes
    }

    function getDepositInfo(address account) external pure returns (IStakeManager.DepositInfo memory) {
        return IStakeManager.DepositInfo({deposit: 0, staked: false, stake: 0, unstakeDelaySec: 0, withdrawTime: 0});
    }

    function senderCreator() external view returns (ISenderCreator) {
        // Return zero address as a mock for testing
        return ISenderCreator(address(0));
    }

    // Original implementation
    function depositInfo(address) external pure returns (IStakeManager.DepositInfo memory) {
        return IStakeManager.DepositInfo({deposit: 0, staked: false, stake: 0, unstakeDelaySec: 0, withdrawTime: 0});
    }

    // Implementing previously missing function
    function getSenderAddress(bytes memory) external view {
        // Empty implementation for the interface requirement
    }
}

contract TrumpFunPaymasterTest is Test {
    // Define local constant for testing - matches the one in the contract
    uint256 private constant PAYMASTER_DATA_OFFSET = 148;

    TrumpFunPaymaster public paymaster;
    MockEntryPoint public entryPoint;
    PointsToken public pointsToken;
    MockUSDC public usdc;

    address public owner;
    address public user;

    function setUp() public {
        // Set up accounts
        owner = address(this);
        user = makeAddr("user");
        vm.deal(owner, 10 ether);
        vm.deal(user, 1 ether);

        // Deploy mock contracts
        entryPoint = new MockEntryPoint();
        pointsToken = new PointsToken("PointsToken", "POINTS", 6, 1_000_000 * 10 ** 6);
        usdc = new MockUSDC();

        // Deploy paymaster
        paymaster =
            new TrumpFunPaymaster(IEntryPoint(address(entryPoint)), IERC20(address(pointsToken)), IERC20(address(usdc)));

        // Fund the paymaster
        paymaster.deposit{value: 1 ether}();

        // Give tokens to the user
        pointsToken.mint(user, 1000 * 10 ** 6); // 1000 POINTS
        usdc.mint(user, 1000 * 10 ** 6); // 1000 USDC

        // Set user context for tests
        vm.startPrank(user);
        pointsToken.approve(address(paymaster), 1000 * 10 ** 6);
        usdc.approve(address(paymaster), 1000 * 10 ** 6);
        vm.stopPrank();
    }

    function testConvertEthToToken() public {
        // Test the conversion function
        uint256 ethAmount = 0.01 ether; // 0.01 ETH
        uint256 tokenAmount = paymaster.convertEthToToken(ethAmount);

        // With 3500 USD/ETH and 3% markup, 0.01 ETH should be about 36.05 USDC/POINTS
        // (0.01 * 3500 * 1.03) = 36.05
        // Since token has 6 decimals, we expect 36.05 * 10^6 = 36050000
        assertApproxEqRel(tokenAmount, 36050000, 0.01e18); // Assert within 1% tolerance
    }

    function testGetDeposit() public {
        assertEq(paymaster.getDeposit(), 1 ether);
    }

    function testSetGasPriceMarkup() public {
        // Default is 300 (3%)
        assertEq(paymaster.gasPriceMarkup(), 300);

        // Set to 5%
        paymaster.setGasPriceMarkup(500);
        assertEq(paymaster.gasPriceMarkup(), 500);
    }

    function testSetMinDepositAmount() public {
        // Default is 0.01 ether
        assertEq(paymaster.minDepositAmount(), 0.01 ether);

        // Set to 0.1 ether
        paymaster.setMinDepositAmount(0.1 ether);
        assertEq(paymaster.minDepositAmount(), 0.1 ether);
    }

    function testSetMinBetAmount() public {
        // Default is 1 USD (1000000 with 6 decimals)
        assertEq(paymaster.minBetAmount(), 1000000);

        // Set to 5 USD
        paymaster.setMinBetAmount(5000000);
        assertEq(paymaster.minBetAmount(), 5000000);
    }

    function testIsBetAmountValid() public {
        // Test with default minimum (1 USD)

        // Valid amounts
        assertTrue(paymaster.isBetAmountValid(1000000, TrumpFunPaymaster.TokenType.USDC)); // 1 USD
        assertTrue(paymaster.isBetAmountValid(5000000, TrumpFunPaymaster.TokenType.PointsToken)); // 5 USD

        // Invalid amounts
        assertFalse(paymaster.isBetAmountValid(999999, TrumpFunPaymaster.TokenType.USDC)); // 0.999999 USD
        assertFalse(paymaster.isBetAmountValid(0, TrumpFunPaymaster.TokenType.PointsToken)); // 0 USD

        // Change minimum and test again
        paymaster.setMinBetAmount(2000000); // 2 USD

        assertFalse(paymaster.isBetAmountValid(1000000, TrumpFunPaymaster.TokenType.USDC)); // 1 USD now invalid
        assertTrue(paymaster.isBetAmountValid(2000000, TrumpFunPaymaster.TokenType.PointsToken)); // 2 USD valid
    }

    function testWithdrawTo() public {
        uint256 initialBalance = address(this).balance;
        paymaster.withdrawTo(payable(address(this)), 0.5 ether);

        // Check paymaster deposit decreased
        assertEq(paymaster.getDeposit(), 0.5 ether);

        // Check owner balance increased
        assertEq(address(this).balance, initialBalance + 0.5 ether);
    }

    // Test a simplified version of validatePaymasterUserOp
    function testValidateWithUSDC() public {
        address mockSender = address(entryPoint);

        // Create a specific format that matches PAYMASTER_DATA_OFFSET
        bytes memory paymasterAndData = new bytes(PAYMASTER_DATA_OFFSET + 64); // 148 + 64 bytes
        // Set the paymaster address at the beginning (20 bytes)
        for (uint256 i = 0; i < 20; i++) {
            paymasterAndData[i] = bytes20(address(paymaster))[i];
        }
        // Add our token data at the correct offset
        bytes memory tokenData = abi.encode(uint8(0), uint256(100 * 10 ** 6)); // TokenType = USDC, 100 USDC max cost
        for (uint256 i = 0; i < 64; i++) {
            paymasterAndData[PAYMASTER_DATA_OFFSET + i] = tokenData[i];
        }

        // Create mock userOp with the paymaster data
        PackedUserOperation memory userOp;
        userOp.sender = user;
        userOp.paymasterAndData = paymasterAndData;

        // Set msg.sender to entryPoint for the validation check
        vm.startPrank(mockSender);

        // Test validation with USDC
        (bytes memory context, uint256 validationData) =
            paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0.01 ether);

        // Check validation succeeded
        assertEq(validationData, 0);
        assertFalse(context.length == 0);

        vm.stopPrank();
    }

    // Helper to receive ETH
    receive() external payable {}
}
