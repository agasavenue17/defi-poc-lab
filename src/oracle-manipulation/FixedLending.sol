// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "../mocks/MockERC20.sol";
import {SimpleAMM} from "./SimpleAMM.sol";

/// @notice Same lending market, but the price comes from a time-weighted
///         average over past observations instead of the live spot price.
///         A single-block pump moves the TWAP by almost nothing, so the
///         manipulation stops paying. (Production markets use hardened
///         oracles such as Chainlink or a long-window Uniswap TWAP; the
///         principle is identical — never lend against a price one
///         transaction can bend.)
contract FixedLending {
    MockERC20 public immutable collateral;
    MockERC20 public immutable debt;
    SimpleAMM public immutable pool;

    uint256 public constant LTV_BPS = 8000;

    // --- minimal TWAP: running average of observed spot prices ---
    uint256 public observationCount;
    uint256 public cumulativePrice;

    mapping(address => uint256) public collateralOf;
    mapping(address => uint256) public debtOf;

    constructor(MockERC20 _collateral, MockERC20 _debt, SimpleAMM _pool) {
        collateral = _collateral;
        debt = _debt;
        pool = _pool;
    }

    /// @notice Record the current spot price as a new observation. In a real
    ///         deployment this is driven by keepers over many blocks; the
    ///         tests call it repeatedly at the honest price before the
    ///         attack, which is exactly the history an attacker faces.
    function observe() external {
        cumulativePrice += pool.spotPriceAinB();
        observationCount += 1;
    }

    function twapPriceAinB() public view returns (uint256) {
        require(observationCount > 0, "no observations");
        return cumulativePrice / observationCount;
    }

    function collateralValueInB(address user) public view returns (uint256) {
        return (collateralOf[user] * twapPriceAinB()) / 1e18;
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
