// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "../mocks/MockERC20.sol";

/// @notice Share vault that prices shares off its raw token balance.
/// @dev VULNERABLE: first-depositor / donation (inflation) attack.
///      The attacker deposits 1 wei, then "donates" a large amount straight
///      to the vault address. The donation inflates the share price so the
///      next depositor's mint rounds down to zero shares, and the attacker
///      redeems the only share for the whole balance.
///      This is the pattern behind a long line of real losses, from early
///      yield aggregators to the ERC-4626 inflation class of bugs.
contract VulnerableVault {
    MockERC20 public immutable asset;

    uint256 public totalShares;
    mapping(address => uint256) public sharesOf;

    constructor(MockERC20 _asset) {
        asset = _asset;
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function deposit(uint256 amount) external returns (uint256 shares) {
        uint256 supply = totalShares;
        uint256 assets = totalAssets();
        shares = supply == 0 ? amount : (amount * supply) / assets;
        asset.transferFrom(msg.sender, address(this), amount);
        totalShares += shares;
        sharesOf[msg.sender] += shares;
    }

    function withdraw(uint256 shares) external returns (uint256 amount) {
        require(sharesOf[msg.sender] >= shares, "shares");
        amount = (shares * totalAssets()) / totalShares;
        sharesOf[msg.sender] -= shares;
        totalShares -= shares;
        asset.transfer(msg.sender, amount);
    }
}
