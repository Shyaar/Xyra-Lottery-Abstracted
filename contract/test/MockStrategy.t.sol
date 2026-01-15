// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/vaults/mockStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC token
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockStrategyTest is Test {
    MockStrategy public strategy;
    MockERC20 public asset;
    address public vault = address(0xVault); // Simulate the vault address

    function setUp() public {
        asset = new MockERC20();
        strategy = new MockStrategy(asset, vault);

        // Mint some assets to the vault so it can deposit
        asset.mint(vault, 1000e6);
    }

    function testDeployment() public {
        assertEq(address(strategy.ASSET()), address(asset));
        assertEq(strategy.VAULT(), vault);
        assertEq(strategy.estimatedTotalAssets(), 0);
    }

    function testDeposit() public {
        uint256 depositAmount = 100e6;
        
        vm.prank(vault);
        asset.approve(address(strategy), depositAmount);

        vm.prank(vault);
        vm.expectEmit(true, false, false, true);
        emit Deposited(depositAmount);
        strategy.deposit(depositAmount);

        assertEq(strategy.estimatedTotalAssets(), depositAmount);
        assertEq(asset.balanceOf(address(strategy)), depositAmount);
        assertEq(asset.balanceOf(vault), 1000e6 - depositAmount);
    }

    function testFail_DepositNotVault() public {
        vm.prank(address(0xNotVault));
        vm.expectRevert("Not vault");
        strategy.deposit(100e6);
    }

    function testFail_DepositZeroAmount() public {
        vm.prank(vault);
        asset.approve(address(strategy), 0); // No need to approve 0 amount
        
        vm.prank(vault);
        vm.expectRevert("Amount > 0");
        strategy.deposit(0);
    }

    function testWithdraw() public {
        // First deposit some funds
        uint256 initialDeposit = 200e6;
        vm.prank(vault);
        asset.approve(address(strategy), initialDeposit);
        vm.prank(vault);
        strategy.deposit(initialDeposit);

        uint256 withdrawAmount = 50e6;
        vm.prank(vault);
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(withdrawAmount, withdrawAmount);
        uint256 actualWithdrawn = strategy.withdraw(withdrawAmount);

        assertEq(actualWithdrawn, withdrawAmount);
        assertEq(strategy.estimatedTotalAssets(), initialDeposit - withdrawAmount);
        assertEq(asset.balanceOf(address(strategy)), initialDeposit - withdrawAmount);
        assertEq(asset.balanceOf(vault), 1000e6 - initialDeposit + withdrawAmount);
    }

    function testWithdrawMoreThanManaged() public {
        // First deposit some funds
        uint256 initialDeposit = 50e6;
        vm.prank(vault);
        asset.approve(address(strategy), initialDeposit);
        vm.prank(vault);
        strategy.deposit(initialDeposit);

        uint256 withdrawAmount = 100e6; // Request more than managed
        vm.prank(vault);
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(withdrawAmount, initialDeposit); // Should withdraw only initialDeposit
        uint256 actualWithdrawn = strategy.withdraw(withdrawAmount);

        assertEq(actualWithdrawn, initialDeposit);
        assertEq(strategy.estimatedTotalAssets(), 0);
        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(asset.balanceOf(vault), 1000e6 - initialDeposit + actualWithdrawn);
    }

    function testFail_WithdrawNotVault() public {
        vm.prank(address(0xNotVault));
        vm.expectRevert("Not vault");
        strategy.withdraw(100e6);
    }

    function testHarvest() public {
        // First deposit some funds to have something to harvest
        uint256 initialDeposit = 100e6;
        vm.prank(vault);
        asset.approve(address(strategy), initialDeposit);
        vm.prank(vault);
        strategy.deposit(initialDeposit);

        vm.prank(vault);
        vm.expectEmit(true, false, false, true);
        emit Harvested(initialDeposit); // According to mock logic, yield is initialDeposit
        uint256 harvestedAmount = strategy.harvest();

        assertEq(harvestedAmount, initialDeposit);
        // totalManaged should remain the same in this mock harvest implementation
        assertEq(strategy.estimatedTotalAssets(), initialDeposit); 
    }

    function testFail_HarvestNotVault() public {
        vm.prank(address(0xNotVault));
        vm.expectRevert("Not vault");
        strategy.harvest();
    }
}
