// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../Moon.sol";

contract MockMoon is Moon {
    constructor(
        Token _token,
        uint256 _hubChainSlug,
        uint256 _chainSlug,
        address _socket
    ) Moon(_token, _hubChainSlug, _chainSlug, _socket) {}

    function mockInBound(bytes memory payload_) external {
        (bytes32 action, bytes memory data) = abi.decode(
            payload_,
            (bytes32, bytes)
        );
        if (action == OP_CREATE_PRIZES) _createPrize(data);
        if (action == OP_APPROVED_WITHDRAW) _approvedWithdraw(data);
        if (action == OP_WITHDRAW_LIQUIDTY) _withdrawLiquidity(data);
        if (action == OP_SYNC_DEPOSIT) _syncDeposit(data);
    }
}
