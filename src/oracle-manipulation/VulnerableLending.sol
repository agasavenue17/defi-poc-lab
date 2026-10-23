// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "../mocks/MockERC20.sol";
import {SimpleAMM} from "./SimpleAMM.sol";

/// @notice Lending market that prices collateral off the AMM's spot price.
/// @dev VULNERABLE: spot-price oracle manipulation — the pattern behind
///      Harvest Finance (2020, $24M), Cheese Bank (2020, $3.3M), and a long
///      tail of lending markets since. One big swap bends the price, the
///      market happily lends against the bent price, and the attacker walks
///      away with the borrow side of the pool.
contract VulnerableLending {
    MockERC20 public immutable collateral; // token A
    MockERC20 public immutable debt; // token B
    SimpleAMM public immutable pool;

    uint256 public constant LTV_BPS = 8000; // borrow up to 80% of collateral value

    mapping(address => uint256) public collateralOf;
    mapping(address => uint256) public debtOf;

    constructor(MockERC20 _collateral, MockERC20 _debt, SimpleAMM _pool) {
        collateral = _collateral;
        debt = _debt;
        pool = _pool;
    }

    function collateralValueInB(address user) public view returns (uint256) {
        return (collateralOf[user] * pool.spotPriceAinB()) / 1e18;
    }

    function depositCollateral(uint256 amount) external {
        collateral.transferFrom(msg.sender, address(this), amount);
        collateralOf[msg.sender] += amount;
    }

    function borrow(uint256 amount) external {
        uint256 maxDebt = (collateralValueInB(msg.sender) * LTV_BPS) / 10_000;
        require(debtOf[msg.sender] + amount <= maxDebt, "over LTV");
        debtOf[msg.sender] += amount;
        debt.transfer(msg.sender, amount);
    }
}
