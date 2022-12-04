// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {ERC4626} from "solmate/mixins/ERC4626.sol";
import "./Token.sol";

contract YieldFarm is ERC4626 {
    Token token;
    uint256 lastDripBlock;
    uint256 rewardMultiplier;

    constructor(
        Token _token,
        string memory _name,
        string memory _symbol
    ) ERC4626(_token, _name, _symbol) {
        token = _token;
        lastDripBlock = block.number;
        rewardMultiplier = 1;
    }

    function totalAssets() public view override returns (uint256) {
        uint256 blocks = block.number - lastDripBlock;
        return token.balanceOf(address(this)) + blocks * rewardMultiplier;
    }

    function _getReward() internal {
        if (lastDripBlock == block.number) return;

        uint256 toMint = (block.number - lastDripBlock) * rewardMultiplier;
        token.mint(address(this), toMint);
    }

    function deposit(
        uint256 tokens,
        address receiver
    ) public override returns (uint256 shares) {
        _getReward();
        return super.deposit(tokens, receiver);
    }

    function mint(
        uint256 shares,
        address receiver
    ) public override returns (uint256 assets) {
        _getReward();
        return super.mint(shares, receiver);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        _getReward();
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        _getReward();
        return super.redeem(shares, receiver, owner);
    }
}
