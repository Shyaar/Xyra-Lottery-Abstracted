// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/registry/UserRegistry.sol";

contract UserRegistryTest is Test {
    UserRegistry public registry;
    address public owner;
    address public user1 = address(1);
    address public user2 = address(2);

    function setUp() public {
        owner = address(this);
        registry = new UserRegistry();
    }

    function testDeployment() public {
        assertEq(registry.owner(), owner);
    }

    function testRegister() public {
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit UserRegistered(user1);
        registry.register();
        assertTrue(registry.isRegistered(user1));
    }

    function testFail_RegisterWhenAlreadyRegistered() public {
        vm.prank(user1);
        registry.register();

        vm.prank(user1);
        vm.expectRevert("User already registered");
        registry.register();
    }

    function testUnregister() public {
        vm.prank(user1);
        registry.register();

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit UserUnregistered(user1);
        registry.unregister();
        assertFalse(registry.isRegistered(user1));
    }

    function testFail_UnregisterWhenNotRegistered() public {
        vm.prank(user1);
        vm.expectRevert("User not registered");
        registry.unregister();
    }
    
    function testMultipleUsers() public {
        // User 1 registers
        vm.prank(user1);
        registry.register();
        assertTrue(registry.isRegistered(user1));
        assertFalse(registry.isRegistered(user2));

        // User 2 registers
        vm.prank(user2);
        registry.register();
        assertTrue(registry.isRegistered(user1));
        assertTrue(registry.isRegistered(user2));

        // User 1 unregisters
        vm.prank(user1);
        registry.unregister();
        assertFalse(registry.isRegistered(user1));
        assertTrue(registry.isRegistered(user2));
    }
}
