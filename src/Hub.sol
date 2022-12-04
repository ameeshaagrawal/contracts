// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./utils/PlugBase.sol";
import "./YieldFarm.sol";
import "./Token.sol";

import "forge-std/console.sol";

contract Hub is PlugBase {
    Token public token;
    YieldFarm public yieldFarm;

    uint256 public totalMoons;
    uint256 public totalDeposits;

    uint256[] public moons;
    address[] public users;

    mapping(address => uint256) public balances;
    mapping(uint256 => uint256) public moonBalances;

    bytes32 HUB_DEPOSIT = keccak256("HUB_DEPOSIT");
    bytes32 OP_SYNC_DEPOSIT = keccak256("OP_SYNC_DEPOSIT");
    bytes32 OP_CREATE_PRIZES = keccak256("OP_CREATE_PRIZES");
    bytes32 HUB_REQUEST_CLAIM = keccak256("HUB_REQUEST_CLAIM");
    bytes32 OP_APPROVED_CLAIM = keccak256("OP_APPROVED_CLAIM");
    string INTEGRATION_TYPE = "FAST";

    uint256 SYNC_BALANCES_GAS_LIMIT = 100000;
    uint256 SYNC_WINNER_GAS_LIMIT = 100000;
    uint256 ONE_WEEK = 1 weeks;
    uint256 public fees = 0;
    mapping(uint256 => mapping(address => bool)) public claimed;

    event ClaimApproved(uint256 indexed id, address indexed receiver, uint256 amount, uint256 moonSlug);

    struct Prize {
        uint256 id;
        uint256 amount;
        uint256 winnerAmount;
        address winnerAddress;
        uint256 expiry;
    }
    Prize[] public prizes;

    constructor(
        address _token,
        address _socket,
        address _yield
    ) PlugBase(_socket) {
        token = Token(_token);
        yieldFarm = YieldFarm(_yield);
    }

    function setupMoons(
        address[] calldata moons_,
        uint256[] calldata chainSlugs_
    ) external onlyOwner {
        for (uint256 index = 0; index < moons_.length; index++) {
            connect(chainSlugs_[index], moons_[index], INTEGRATION_TYPE);
            moons.push(chainSlugs_[index]);
        }

        totalMoons += moons_.length;
    }

    function getPrizes(
        uint256 index
    )
        external
        view
        returns (
            uint256 id,
            uint256 amount,
            uint256 winnerAmount,
            address winnerAddress,
            uint256 expiry
        )
    {
        Prize memory prize = prizes[index];
        return (
            prize.id,
            prize.amount,
            prize.winnerAmount,
            prize.winnerAddress,
            prize.expiry
        );
    }

    function declareWinner() external  {
        if(prizes.length > 0)require(block.timestamp > prizes[prizes.length - 1].expiry, "Prize already active");
        uint256 interest = yieldFarm.maxWithdraw(address(this)) - totalDeposits;
        uint256 totalUsers = users.length;

        // random winner
        uint256 randomIndex = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.difficulty, msg.sender)
            )
        ) % totalUsers;

        uint256 winnerAmount = (interest * 50) / 100;
        uint256 amount = (interest - winnerAmount) / (totalUsers - 1);

        Prize memory prize;

        prize.amount = amount;
        prize.expiry = block.timestamp + ONE_WEEK;
        prize.id = prizes.length == 0 ? 1 : prizes.length;
        prize.winnerAddress = users[randomIndex];
        prize.winnerAmount = winnerAmount;
        prizes.push(prize);

        bytes memory payload = abi.encode(
            prize.winnerAmount,
            prize.amount,
            prize.expiry,
            prize.winnerAddress,
            prize.id
        );

        payload = abi.encode(OP_CREATE_PRIZES, payload);
        _broadcast(type(uint256).max, SYNC_WINNER_GAS_LIMIT, payload);
    }

    function _receiveInbound(bytes memory payload_) internal override {
        (bytes32 action, bytes memory data) = abi.decode(
            payload_,
            (bytes32, bytes)
        );

        if (action == HUB_DEPOSIT) _deposit(data);
        if (action == HUB_REQUEST_CLAIM) _processClaim(data);
    }

    function _processClaim(bytes memory payload) internal {
        (address receiver, uint256 id, uint256 moonChainId) = abi.decode(payload,
            (address, uint256, uint256)
        );
        if(claimed[id][receiver]) return;
        Prize memory prize = prizes[id];
        if(prize.expiry < block.timestamp) return;
        if(prize.winnerAddress == receiver) {
          bytes memory data = abi.encode(id, prize.winnerAmount ,receiver);
          bytes memory finalPayload  = abi.encode(OP_APPROVED_CLAIM, data);
            outbound(moonChainId, SYNC_WINNER_GAS_LIMIT, fees, finalPayload);
             emit ClaimApproved(id, receiver, prize.winnerAmount, moonChainId);
           
        } else {
         bytes memory data = abi.encode(id, prize.amount ,receiver);
         bytes memory finalPayload  = abi.encode(OP_APPROVED_CLAIM, data);
            outbound(moonChainId, SYNC_WINNER_GAS_LIMIT, fees, finalPayload);
             emit ClaimApproved(id, receiver, prize.amount, moonChainId);
        }
        claimed[id][receiver] = true;
    }

    function _deposit(bytes memory payload_) internal {
        (address user, uint256 amount, uint256 moonChainId) = abi.decode(
            payload_,
            (address, uint256, uint256)
        );

        if (balances[user] == 0) users.push(user);
        balances[user] += amount;
        moonBalances[moonChainId] += amount;
        totalDeposits += amount;

        bytes memory payload = abi.encode(user, balances[user]);
        payload = abi.encode(OP_SYNC_DEPOSIT, payload);

        _broadcast(moonChainId, SYNC_BALANCES_GAS_LIMIT, payload);

        token.mint(address(this), amount);
        token.approve(address(yieldFarm), amount);

        yieldFarm.deposit(amount, address(this));
    }

    function _broadcast(
        uint256 moonChainId,
        uint256 gasLimit,
        bytes memory payload
    ) internal {
        for (uint256 index = 0; index < totalMoons; index++) {
            if (moons[index] == moonChainId) return;
            outbound(moons[index], gasLimit, fees, payload);
        }
    }

    // rescue and setter functions
    function rescueFunds(address _to, uint256 _amount) external onlyOwner {
        token.transfer(_to, _amount);
    }

    function rescueEther(
        address payable _to,
        uint256 _amount
    ) external onlyOwner {
        _to.transfer(_amount);
    }

    function setFees(uint256 _fees) external onlyOwner {
        fees = _fees;
    }

    // mocks
    function mockInbound(bytes memory payload_) external {
        _receiveInbound(payload_);
    }
}
