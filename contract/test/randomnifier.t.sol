// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/randomnifier/randomnifier.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

// Mock VRFCoordinatorV2
contract MockVRFCoordinator is VRFCoordinatorV2Interface {
    function getRequestConfig()
        external
        pure
        returns (
            uint16,
            uint32,
            bytes32[] memory
        )
    {
        return (1, 1, new bytes32[](0));
    }

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32
    ) external pure returns (uint256) {
        return 1;
    }
    
    function acceptSubscriptionOwnerTransfer(uint64) external {}
    function addConsumer(uint64, address) external {}
    function removeConsumer(uint64, address) external {}
    function requestSubscriptionOwnerTransfer(uint64, address) external {}
    function cancelSubscription(uint64, address) external {}
    function getSubscription(uint64) external pure returns (uint96, uint64, address, address[] memory) {
        return (1,1,address(0), new address[](0));
    }
    function createSubscription() external pure returns (uint64) { return 1; }
    function pendingRequestExists(uint64) external pure returns (bool) { return false; }
}


// Mock LotteryManager Callback
contract MockLotteryManager is ILotteryManagerCallback {
    uint256 public receivedRequestId;
    uint256 public receivedRandomness;

    function receiveRandomness(uint256 requestId, uint256 randomness) external {
        receivedRequestId = requestId;
        receivedRandomness = randomness;
    }
}

contract RandomnifierTest is Test {
    Randomifier public randomnifier;
    MockVRFCoordinator public mockCoordinator;
    MockLotteryManager public mockLotteryManager;

    address public owner;
    address public requester = address(1);

    bytes32 public keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint64 public subscriptionId = 1;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;

    function setUp() public {
        owner = address(this);
        mockCoordinator = new MockVRFCoordinator();
        mockLotteryManager = new MockLotteryManager();

        randomnifier = new Randomifier(
            address(mockCoordinator),
            subscriptionId,
            keyHash,
            callbackGasLimit,
            requestConfirmations
        );

        randomnifier.setRequester(requester);
        randomnifier.setConsumerCallback(address(mockLotteryManager));
    }

    function testDeployment() public {
        assertEq(address(randomnifier.owner()), owner);
        assertEq(randomnifier.requester(), requester);
        assertEq(randomnifier.consumerCallback(), address(mockLotteryManager));
        assertEq(randomnifier.subscriptionId(), subscriptionId);
        assertEq(randomnifier.keyHash(), keyHash);
    }

    function testSetters() public {
        address newRequester = address(2);
        randomnifier.setRequester(newRequester);
        assertEq(randomnifier.requester(), newRequester);

        address newConsumer = address(3);
        randomnifier.setConsumerCallback(newConsumer);
        assertEq(randomnifier.consumerCallback(), newConsumer);

        uint64 newSubId = 2;
        bytes32 newKeyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b345b8430a5d;
        uint32 newGasLimit = 200000;
        uint16 newConfirmations = 5;

        randomnifier.setVRFParams(newSubId, newKeyHash, newGasLimit, newConfirmations);
        assertEq(randomnifier.subscriptionId(), newSubId);
        assertEq(randomnifier.keyHash(), newKeyHash);
        assertEq(randomnifier.callbackGasLimit(), newGasLimit);
        assertEq(randomnifier.requestConfirmations(), newConfirmations);
    }

    function testFail_SettersNotOwner() public {
        vm.prank(requester);
        vm.expectRevert("Ownable: caller is not the owner");
        randomnifier.setRequester(address(2));

        vm.prank(requester);
        vm.expectRevert("Ownable: caller is not the owner");
        randomnifier.setConsumerCallback(address(3));
        
        vm.prank(requester);
        vm.expectRevert("Ownable: caller is not the owner");
        randomnifier.setVRFParams(2, keyHash, callbackGasLimit, requestConfirmations);
    }

    function testRequestRandomness() public {
        vm.prank(requester);
        vm.expectEmit(true, true, false, true);
        emit RandomRequested(1, requester);
        uint256 requestId = randomnifier.requestRandomness();
        assertEq(requestId, 1);
    }

    function testFail_RequestRandomnessNotAuthorized() public {
        vm.prank(address(99)); // Some random address
        vm.expectRevert("Not authorized");
        randomnifier.requestRandomness();
    }
    
    function testFulfillRandomWords() public {
        uint256 requestId = 1;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;

        vm.expectEmit(true, false, false, true);
        emit RandomFulfilled(requestId, 12345);
        
        // The callback to fulfillRandomWords is made by the VRFCoordinator
        // We simulate this by getting a raw reference to the contract
        // and calling the function.
        bytes memory callData = abi.encodeCall(randomnifier.fulfillRandomWords, (requestId, randomWords));
        (bool success, ) = address(randomnifier).call(callData);
        assertTrue(success);

        assertEq(mockLotteryManager.receivedRequestId(), requestId);
        assertEq(mockLotteryManager.receivedRandomness(), 12345);
    }
}
