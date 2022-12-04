// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./utils/PlugBase.sol";
import "./Token.sol";
struct Prize {
    uint256 id;
    uint256 amount;
    uint256 winnerAmount;
    address winnerAddress;
    uint256 expiry;
}

contract Moon is PlugBase {
    using SafeERC20 for Token;
    Token public token;
    address public hub;
    uint256 public hubChainSlug;
    uint256 public chainSlug;

    uint256 public fees = 0;

    mapping(address => uint256) public balances;
    mapping(uint256 => Prize) public prizes;
    address[] users;
    mapping(uint256 => mapping(address => bool)) public claimed;

    uint256 public latestId;

    bytes32 OP_CREATE_PRIZES = keccak256("OP_CREATE_PRIZES");
    bytes32 OP_APPROVED_CLAIM = keccak256("OP_APPROVED_CLAIM");
    bytes32 OP_APPROVED_WITHDRAW = keccak256("OP_APPROVED_WITHDRAW");
    bytes32 OP_DEPOSIT_LIQUIDTY = keccak256("OP_DEPOSIT_LIQUIDTY");
    bytes32 OP_WITHDRAW_LIQUIDTY = keccak256("OP_WITHDRAW_LIQUIDTY");
    bytes32 HUB_DEPOSIT = keccak256("HUB_DEPOSIT");
    bytes32 OP_SYNC_DEPOSIT = keccak256("OP_SYNC_DEPOSIT");
    bytes32 HUB_REQUEST_CLAIM = keccak256("HUB_REQUEST_CLAIM");

    uint256 CREATE_PRIZES_GAS_LIMIT = 100000;
    uint256 APPROVED_CLAIM_GAS_LIMIT = 100000;
    uint256 APPROVED_WITHDRAW_GAS_LIMIT = 100000;
    uint256 DEPOSIT_LIQUIDTY_GAS_LIMIT = 100000;
    uint256 WITHDRAW_LIQUIDTY_GAS_LIMIT = 100000;

    event FundsDeposited(address indexed sender, uint256 amount);
    event FundsAdded(uint256 amount);
    event FundsRemoved(uint256 amount);
    event SyncBalance(address indexed sender, uint256 balance);
    event ClaimRequestSubmited(uint256 indexed id, uint256 receiver);
    event ClaimedEvent(uint256 indexed id, address receiver, uint256 amount);

    constructor(
        Token _token,
        address _hub,
        uint256 _hubChainSlug,
        uint256 _chainSlug,
        address _socket
    ) PlugBase(_socket) {
        token = _token;
        hub = _hub;
        hubChainSlug = _hubChainSlug;
        chainSlug = _chainSlug;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

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

    function setHub(address _hub) external onlyOwner {
        hub = _hub;
    }

    function setHubChainSlug(uint256 _hubChainSlug) external onlyOwner {
        hubChainSlug = _hubChainSlug;
    }

    function deposit(uint256 _amount) external {
        token.transferFrom(msg.sender, address(this), _amount);
        balances[msg.sender] += _amount;
        bytes memory _payload = abi.encode(msg.sender, _amount, chainSlug);
        bytes memory payload = abi.encode(HUB_DEPOSIT, _payload);
        outbound(hubChainSlug, DEPOSIT_LIQUIDTY_GAS_LIMIT, fees, payload);
        token.burn(address(this), _amount);
    }

    function _createPrize(bytes memory payload) internal {
        (
            uint256 winnerAmount,
            uint256 amount,
            uint256 expiry,
            address receiver,
            uint256 id
        ) = abi.decode(payload, (uint256, uint256, uint256, address, uint256));
        prizes[id] = Prize(id, amount, winnerAmount, receiver, expiry);
        latestId = id;

        // reset claimed
        for (uint256 i = 0; i < users.length; i++) {
            claimed[id][users[i]] = false;
        }
    }

    function getPrizeMoneyAmount() public view returns (uint256) {
        require(latestId > 0, "No prize money");
        uint256 amount = prizes[latestId].amount;
        uint256 winnerAmount = prizes[latestId].winnerAmount;
        uint256 expiry = prizes[latestId].expiry;
        address winnerAddress = prizes[latestId].winnerAddress;
        if (expiry < block.timestamp) return 0;
        if (winnerAddress == address(0)) return 0;
        if (claimed[latestId][msg.sender]) return 0;
        if (winnerAddress == msg.sender) return winnerAmount;
        return amount;
    }

    function requestClaim() external {
        uint256 amount = getPrizeMoneyAmount();
        require(amount > 0, "No prize money");
        bytes memory _payload = abi.encode(msg.sender, latestId, chainSlug);
        bytes memory payload = abi.encode(HUB_REQUEST_CLAIM, _payload);
        outbound(hubChainSlug, DEPOSIT_LIQUIDTY_GAS_LIMIT, fees, payload);
    }

    function _approvedClaim(bytes memory payload) internal {
        (uint256 id, uint256 amount, address receiver) = abi.decode(
            payload,
            (uint256, uint256, address)
        );
        token.mint(address(this), amount);
        token.transfer(receiver, amount);
        claimed[id][msg.sender] = true;
        users.push(msg.sender);
        emit ClaimedEvent(id, receiver, amount);
    }

    function _approvedWithdraw(bytes memory payload) internal {
        uint256 amount = abi.decode(payload, (uint256));
        token.transfer(msg.sender, amount);
    }

    // function _depositLiquidity(bytes memory payload) internal {
    //     (uint256 amount) = abi.decode(payload, (uint256));
    //     token.mint(address(this), amount);
    //     emit FundsAdded(amount);
    // }

    function _withdrawLiquidity(bytes memory payload) internal {
        uint256 amount = abi.decode(payload, (uint256));
        // token.burn(address(this), amount);
        emit FundsRemoved(amount);
    }

    function _syncDeposit(bytes memory payload) internal {
        (address sender, uint256 balance) = abi.decode(
            payload,
            (address, uint256)
        );
        balances[sender] = balance;
        emit SyncBalance(sender, balance);
    }

    function _receiveInbound(bytes memory payload_) internal override {
        (bytes32 action, bytes memory data) = abi.decode(
            payload_,
            (bytes32, bytes)
        );
        // if(action == OP_CREATE_PRIZES) _createPrize(data);
        // if(action == OP_APPROVED_CLAIM) _approvedClaim(data);
        if (action == OP_APPROVED_WITHDRAW) _approvedWithdraw(data);
        // if(action == OP_DEPOSIT_LIQUIDTY) _depositLiquidity(data);
        if (action == OP_WITHDRAW_LIQUIDTY) _withdrawLiquidity(data);
        if (action == OP_SYNC_DEPOSIT) _syncDeposit(data);
    }

    function mockInBound(bytes memory payload_) external {
        (bytes32 action, bytes memory data) = abi.decode(
            payload_,
            (bytes32, bytes)
        );
        // if(action == OP_CREATE_PRIZES) _createPrize(data);
        // if(action == OP_APPROVED_CLAIM) _approvedClaim(data);
        if (action == OP_APPROVED_WITHDRAW) _approvedWithdraw(data);
        // if(action == OP_DEPOSIT_LIQUIDTY) _depositLiquidity(data);
        if (action == OP_WITHDRAW_LIQUIDTY) _withdrawLiquidity(data);
        if (action == OP_SYNC_DEPOSIT) _syncDeposit(data);
    }
}
