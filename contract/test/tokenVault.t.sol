// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/vaults/tokenVault.sol";
import "../src/vaults/mockStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenVaultTest is Test {
    TokenVault public vault;
    MockStrategy public strategy;
    ERC20 public asset;

    address public owner;
    address public alice = address(1);
    address public bob = address(2);

    function setUp() public {
        owner = address(this);
        asset = new ERC20("Mock Asset", "MAT");
        vault = new TokenVault(asset, "Vault Token", "VT");

        // Mint assets for users
        asset.mint(alice, 1000e18);
        asset.mint(bob, 1000e18);
        
        // Setup strategy
        strategy = new MockStrategy(asset, address(vault));
        vault.setStrategy(strategy);
    }

    function testDeployment() public {
        assertEq(address(vault.asset()), address(asset));
        assertEq(vault.owner(), owner);
        assertEq(vault.name(), "Vault Token");
        assertEq(vault.symbol(), "VT");
    }

    function testERC4626DepositAndWithdraw() public {
        uint256 depositAmount = 100e18;
        
        // Alice deposits
        vm.prank(alice);
        asset.approve(address(vault), depositAmount);
        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        assertEq(vault.balanceOf(alice), depositAmount); // 1:1 shares for initial deposit
        assertEq(vault.totalAssets(), depositAmount);
        assertEq(asset.balanceOf(address(vault)), depositAmount);

        // Alice withdraws half
        uint256 withdrawAmount = 50e18;
        vm.prank(alice);
        vault.withdraw(withdrawAmount, alice, alice);

        assertEq(vault.balanceOf(alice), depositAmount - withdrawAmount);
        assertEq(vault.totalAssets(), depositAmount - withdrawAmount);
        assertEq(asset.balanceOf(address(vault)), depositAmount - withdrawAmount);
        assertEq(asset.balanceOf(alice), 1000e18 - depositAmount + withdrawAmount);
    }

    function testSetStrategy() public {
        MockStrategy newStrategy = new MockStrategy(asset, address(vault));
        vm.expectEmit(true, true, true, true);
        emit StrategyUpdated(address(strategy), address(newStrategy));
        vault.setStrategy(newStrategy);
        assertEq(address(vault.strategy()), address(newStrategy));
    }

    function testEarnAndHarvest() public {
        // Alice deposits into the vault
        uint256 depositAmount = 100e18;
        vm.prank(alice);
        asset.approve(address(vault), depositAmount);
        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        // Earn and Harvest
        vm.expectEmit(true, false, false, true);
        emit EarnedToStrategy(depositAmount);
        vault.earnAndHarvest();

        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(address(strategy)), depositAmount);
        assertEq(strategy.estimatedTotalAssets(), depositAmount);
        assertEq(vault.totalAssets(), depositAmount);
    }

    function testWithdrawFromStrategy() public {
        // Alice deposits and vault earns
        uint256 depositAmount = 100e18;
        vm.prank(alice);
        asset.approve(address(vault), depositAmount);
        vm.prank(alice);
        vault.deposit(depositAmount, alice);
        vault.earnAndHarvest();
        
        // Withdraw from strategy
        uint256 withdrawAmount = 50e18;
        vm.expectEmit(true, false, false, true);
        emit WithdrawnFromStrategy(withdrawAmount, withdrawAmount);
        vault.withdrawFromStrategy(withdrawAmount);

        assertEq(asset.balanceOf(address(vault)), withdrawAmount);
        assertEq(strategy.estimatedTotalAssets(), depositAmount - withdrawAmount);
        assertEq(vault.totalAssets(), depositAmount);
    }
    
    function testHarvest() public {
        // Alice deposits and vault earns
        uint256 depositAmount = 100e18;
        vm.prank(alice);
        asset.approve(address(vault), depositAmount);
        vm.prank(alice);
        vault.deposit(depositAmount, alice);
        vault.earnAndHarvest();

        // Harvest
        vm.expectEmit(true, false, false, true);
        emit Harvested(depositAmount);
        uint harvested = vault.harvest();
        
        assertEq(harvested, depositAmount);
    }

    function testEmergencyWithdraw() public {
        // Alice deposits and vault earns
        uint256 depositAmount = 200e18;
        vm.prank(alice);
        asset.approve(address(vault), depositAmount);
        vm.prank(alice);
        vault.deposit(depositAmount, alice);
        vault.earnAndHarvest();

        // Emergency withdraw
        vault.emergencyWithdrawAllFromStrategy();
        
        assertEq(vault.totalAssets(), depositAmount);
        assertEq(asset.balanceOf(address(vault)), depositAmount);
        assertEq(strategy.estimatedTotalAssets(), 0);
    }
    
    function testRecoverERC20() public {
        ERC20 otherToken = new ERC20("Other Token", "OTK");
        otherToken.mint(address(vault), 500);

        vault.recoverERC20(otherToken, owner, 500);
        assertEq(otherToken.balanceOf(owner), 500);
    }
    
    function testFail_RecoverVaultAsset() public {
        vm.expectRevert("Cannot recover vault asset");
        vault.recoverERC20(asset, owner, 1);
    }
}
