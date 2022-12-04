// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../Hub.sol";

contract MockHub is Hub {
    constructor(
        address _token,
        address _socket,
        address _yield
    ) Hub(_token, _socket, _yield) {}

    function mockInbound(bytes memory payload_) external {
        _receiveInbound(payload_);
    }
}
