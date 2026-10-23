// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "../mocks/MockERC20.sol";

/// @notice Constant-product pool (Uniswap V2 shape, no fees, no LP tokens —
///         the tests seed and drain it directly). Its spot price is what the
///         vulnerable lending market trusts.
contract SimpleAMM {
    MockERC20 public immutable tokenA;
    MockERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    constructor(MockERC20 _tokenA, MockERC20 _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);
        reserveA += amountA;
        reserveB += amountB;
    }

    /// @notice Price of A denominated in B, scaled by 1e18. This is a spot
    ///         price: whoever moves the reserves moves the "oracle".
    function spotPriceAinB() public view returns (uint256) {
        require(reserveA > 0, "no liquidity");
        return (reserveB * 1e18) / reserveA;
    }

    /// @notice Swap B for A at the pool's constant-product curve.
    function swapBforA(uint256 amountBIn) external returns (uint256 amountAOut) {
        tokenB.transferFrom(msg.sender, address(this), amountBIn);
        amountAOut = (amountBIn * reserveA) / (reserveB + amountBIn);
        reserveB += amountBIn;
        reserveA -= amountAOut;
        tokenA.transfer(msg.sender, amountAOut);
    }

    /// @notice Swap A for B (the way back out of a pump).
    function swapAforB(uint256 amountAIn) external returns (uint256 amountBOut) {
        tokenA.transferFrom(msg.sender, address(this), amountAIn);
        amountBOut = (amountAIn * reserveB) / (reserveA + amountAIn);
        reserveA += amountAIn;
        reserveB -= amountBOut;
        tokenB.transfer(msg.sender, amountBOut);
    }
}
