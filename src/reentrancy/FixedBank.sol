// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Same bank, fixed with checks-effects-interactions: the balance is
///         settled before any external call, so a re-entered withdraw() sees
///         a zero balance and reverts. (A reentrancy guard reaches the same
///         result; ordering alone is enough here and keeps the lesson plain.)
contract FixedBank {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "nothing to withdraw");
        balances[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "send failed");
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }
}
