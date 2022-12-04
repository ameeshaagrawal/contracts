// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Moon.sol";
import "../src/Token.sol";

contract MoonTesting is Test {
    Moon public moon;
    Token public token;
    

    function setUp() public {
        uint256 fork = vm.createFork("https://goerli.optimism.io");
        vm.selectFork(fork);
        token = new Token("USDC COIN", "USDC", 6);
        moon = new Moon(token, address(this), 80001,420, 0x05501406bCC171b543db0A2C547b7cB68D9D69E3);
        moon.connect(80001, 0x32a80b98e33c3A0E57D635C56707208D29f970a2, "FAST");

    }

    function testMoonDeposit() public {
        vm.startPrank(0x86791C7b7Ea5F77b1612eCc300dD44ba3A1C9083);

        uint256 amount = 10000000;
        token.mint( 0x86791C7b7Ea5F77b1612eCc300dD44ba3A1C9083, amount);
        token.approve(address(moon), amount);
        moon.deposit(amount);
        moon.balances(0x86791C7b7Ea5F77b1612eCc300dD44ba3A1C9083);
        console.log("balance", moon.balances(0x86791C7b7Ea5F77b1612eCc300dD44ba3A1C9083));
        vm.stopPrank();
        // counter.increment();
        // assertEq(counter.number(), 1);
    }

    function testSyncDeposit() public {
        bytes32 OP_SYNC_DEPOSIT = keccak256("OP_SYNC_DEPOSIT");

        vm.startPrank(0x86791C7b7Ea5F77b1612eCc300dD44ba3A1C9083);
        bytes memory data = abi.encode(0x86791C7b7Ea5F77b1612eCc300dD44ba3A1C9083, 50000000);
        bytes memory payload = abi.encode(OP_SYNC_DEPOSIT, data);
        moon.mockInBound(payload);
        console.log("balance", moon.balances(0x86791C7b7Ea5F77b1612eCc300dD44ba3A1C9083));
        vm.stopPrank();
    }

    // function testSetNumber(uint256 x) public {
    //     // counter.setNumber(x);
    //     // assertEq(counter.number(), x);
    // }
}
