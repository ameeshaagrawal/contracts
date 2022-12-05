// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../src/mocks/MockHub.sol";
import "../src/mocks/MockMoon.sol";
import "../src/YieldFarm.sol";
import "../src/Token.sol";

contract HubTesting is Test {
    MockHub public hub;
    MockMoon public moon;
    Token public token;
    YieldFarm public yieldFarm;

    address user1 = address(1);
    address user2 = address(2);
    address user3 = address(3);
    address user4 = address(4);

    address socket = 0x05501406bCC171b543db0A2C547b7cB68D9D69E3;
    address remotePlug = 0x05501406bCC171b543db0A2C547b7cB68D9D69E3;

    uint256 fork;
    uint256 chainSlug = 80001;
    uint256 hubChainSlug = 420;

    address[] moons;
    uint256[] chains;
    uint256[] remotes = [80001, 421613];
    address[] users = [user1, user2]; //, user3, user4];

    function setUp() public {
        fork = vm.createFork("https://goerli.optimism.io");
        vm.selectFork(fork);

        token = new Token("USDC COIN", "USDC", 6);
        yieldFarm = new YieldFarm(token, "USDC COIN", "USDC");
        hub = new MockHub(address(token), socket, address(yieldFarm));

        for (uint256 index = 0; index < remotes.length; index++) {
            moon = new MockMoon(
                token,
                hubChainSlug,
                chainSlug,
                socket
            );
            moons.push(address(moon));
        }

        hub.setupMoons(moons, remotes);
    }

    function testDeposit() public {
        vm.startPrank(user1);
        uint256 amount = 1000;
        bytes memory payload = abi.encode(user1, amount, moons[0]);
        payload = abi.encode(keccak256("HUB_DEPOSIT"), payload);
        hub.mockInbound(payload);

        assertEq(token.balanceOf(address(yieldFarm)), amount);
        assertEq(hub.balances(user1), amount);

        vm.stopPrank();
    }

    function testDeclarePrize() public {
        uint256 deposit = 1000;
        for (uint256 index = 0; index < users.length; index++) {
            // deposit
            vm.startPrank(users[index]);
            bytes memory payload = abi.encode(users[index], deposit, moons[0]);
            payload = abi.encode(keccak256("HUB_DEPOSIT"), payload);
            hub.mockInbound(payload);
            vm.stopPrank();
        }

        hub.declareWinner();

        (
            uint256 id,
            uint256 amount,
            uint256 winnerAmount,
            address winnerAddress,
            uint256 expiry
        ) = hub.getPrizes(0);

        console.log(id);
        console.log(amount);
        console.log(winnerAmount);
        console.log(winnerAddress);
        console.log(expiry);
    }
}
