// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "../mocks/MockERC20.sol";

/// @notice Same vault interface as VulnerableVault, with two defences:
///         1. Internal accounting: the vault prices shares off the assets it
///            tracked through deposit()/withdraw(), so a direct transfer
///            ("donation") to the vault address is ignored instead of moving
///            the share price. Unsolicited tokens are simply stranded.
///         2. A virtual shares/assets offset (the OpenZeppelin ERC-4626
///            defence), so even the first-depositor edge case cannot make a
///            later deposit round down to zero.
contract FixedVault {
    MockERC20 public immutable asset;

    uint256 public totalShares;
    uint256 public trackedAssets;
    mapping(address => uint256) public sharesOf;

    uint256 internal constant VIRTUAL_SHARES = 1e6;
    uint256 internal constant VIRTUAL_ASSETS = 1;

    constructor(MockERC20 _asset) {
        asset = _asset;
    }

    function totalAssets() public view returns (uint256) {
        return trackedAssets;
    }

    function deposit(uint256 amount) external returns (uint256 shares) {
        shares = (amount * (totalShares + VIRTUAL_SHARES)) / (trackedAssets + VIRTUAL_ASSETS);
        require(shares > 0, "zero shares");
        asset.transferFrom(msg.sender, address(this), amount);
        trackedAssets += amount;
        totalShares += shares;
        sharesOf[msg.sender] += shares;
    }

    function withdraw(uint256 shares) external returns (uint256 amount) {
        require(sharesOf[msg.sender] >= shares, "shares");
        amount = (shares * (trackedAssets + VIRTUAL_ASSETS)) / (totalShares + VIRTUAL_SHARES);
        sharesOf[msg.sender] -= shares;
        totalShares -= shares;
        trackedAssets -= amount;
        asset.transfer(msg.sender, amount);
    }
}
