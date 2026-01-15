// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/lottery/lotteryManager.sol";
import "../src/vaults/tokenVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC token
class MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// Mock TokenVault
class MockTokenVault is TokenVault {
    uint256 public totalUnderlying;

    constructor(IERC20 _asset) TokenVault(_asset) {}

    function totalAssets() public view override returns (uint256) {
        return totalUnderlying;
    }

    function deposit(uint256 amount, address to) public override returns (uint256) {
        totalUnderlying += amount;
        _mint(to, amount);
        return amount;
    }

    function redeem(uint256 shares, address to, address from) public override returns (uint256) {
        totalUnderlying -= shares;
        _burn(from, shares);
        MockUSDC(address(asset)).transfer(to, shares);
        return shares;
    }

    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return shares;
    }

    function convertToShares(uint256 assets) public view override returns (uint256) {
        return assets;
    }

    function setTotalAssets(uint256 _totalAssets) public {
        totalUnderlying = _totalAssets;
    }
}

// Mock Randomifier
interface IRandomifier {
    function requestRandomness() external returns (uint256);
    function setRandomness(uint256 _randomness) external;
    function randomness() external view returns(uint256);
}


contract LotteryManagerTest is Test {
    LotteryManager public lottery;
    MockUSDC public usdc;
    MockTokenVault public vault;
    IRandomifier public randomifier;

    address public owner;
    address public alice = address(1);
    address public bob = address(2);

    function setUp() public {
        owner = address(this);
        usdc = new MockUSDC();
        vault = new MockTokenVault(usdc);
        
        // Deploy MockRandomifier and get its address
        address randomifierAddress = address(new MockRandomifier());
        randomifier = IRandomifier(randomifierAddress);

        lottery = new LotteryManager(usdc, vault);
        lottery.setRandomifier(randomifierAddress);

        usdc.mint(alice, 1000e6);
        usdc.mint(bob, 1000e6);
    }

    function testDeployment() public {
        assertEq(address(lottery.USDC()), address(usdc));
        assertEq(address(lottery.VAULT()), address(vault));
        assertEq(lottery.owner(), owner);
        assertEq(lottery.roundActive(), false);
        assertEq(lottery.roundId(), 0);
    }

    function testStartRound() public {
        lottery.startRound(60);
        assertTrue(lottery.roundActive());
        assertEq(lottery.roundId(), 1);
        assertEq(lottery.roundEndTimestamp(), block.timestamp + 60);
    }

    function testFail_StartRoundWhenActive() public {
        lottery.startRound(60);
        vm.expectRevert();
        lottery.startRound(60);
    }

    function testCloseRound() public {
        lottery.startRound(60);
        vm.warp(block.timestamp + 61);
        lottery.closeRound();
        assertFalse(lottery.roundActive());
        assertTrue(lottery.awaitingRandomness());
    }

    function testFail_CloseRoundWhenNotActive() public {
        vm.expectRevert();
        lottery.closeRound();
    }

    function testFail_CloseRoundBeforeEnd() public {
        lottery.startRound(60);
        vm.expectRevert();
        lottery.closeRound();
    }

    function testBuyTicket() public {
        lottery.startRound(60);
        vm.prank(alice);
        usdc.approve(address(lottery), 100e6);
        
        uint256 aliceInitialBalance = usdc.balanceOf(alice);
        lottery.buyTicket(100e6);
        
        assertEq(lottery.sharesOf(alice), 100e6);
        assertEq(lottery.totalPrincipal(), 100e6);
        assertEq(usdc.balanceOf(alice), aliceInitialBalance - 100e6);
        assertEq(usdc.balanceOf(address(lottery)), 0); // USDC is transferred to vault
        assertEq(vault.balanceOf(address(lottery)), 100e6); // lottery contract has vault shares
    }

    function testFail_BuyTicketWhenNotActive() public {
        vm.prank(alice);
        usdc.approve(address(lottery), 100e6);
        vm.expectRevert();
        lottery.buyTicket(100e6);
    }
    
    function testWinnerSelectionAndClaim() public {
        lottery.startRound(60);

        vm.prank(alice);
        usdc.approve(address(lottery), 100e6);
        lottery.buyTicket(100e6);

        vm.prank(bob);
        usdc.approve(address(lottery), 200e6);
        lottery.buyTicket(200e6);

        vm.warp(block.timestamp + 61);
        lottery.closeRound();

        // Simulate yield
        vault.setTotalAssets(350e6); 
        
        randomifier.setRandomness(1); // pick bob
        lottery.receiveRandomness(1, randomifier.randomness());

        assertEq(lottery.winner(), bob);
        assertEq(lottery.prizeAmountRedeemed(), 50e6);

        uint256 bobInitialBalance = usdc.balanceOf(bob);

        vm.prank(bob);
        lottery.claimPrize();

        assertEq(usdc.balanceOf(bob), bobInitialBalance + 250e6); // prize + principal
        assertTrue(lottery.prizeClaimed());

        // Alice claims principal
        uint256 aliceInitialBalance = usdc.balanceOf(alice);
        vm.prank(alice);
        lottery.claimPrincipal();

        assertEq(usdc.balanceOf(alice), aliceInitialBalance + 100e6);
    }

    function testSetRoundDuration() public {
        lottery.setRoundDuration(120);
        assertEq(lottery.roundDuration(), 120);
    }

    function testFail_SetRoundDurationZero() public {
        vm.expectRevert();
        lottery.setRoundDuration(0);
    }
}
// MockRandomifier contract implementation
contract MockRandomifier is IRandomifier {
    uint256 public randomness;
    address public caller;

    function requestRandomness() external override returns (uint256) {
        caller = msg.sender;
        return 1;
    }

    function setRandomness(uint256 _randomness) external override {
        randomness = _randomness;
    }
    
    function randomness() external view override returns (uint256) {
        return randomness;
    }
}