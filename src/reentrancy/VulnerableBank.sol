// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Ether bank that sends before it settles.
/// @dev VULNERABLE: withdraw() makes the external call first and zeroes the
///      balance afterwards, so a contract depositor can re-enter withdraw()
///      from its receive() hook and drain the bank — the exact shape of
///      The DAO (2016, ~3.6M ETH) and a pattern that kept reappearing,
///      e.g. Cream Finance (2021, $130M).
contract VulnerableBank {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "nothing to withdraw");
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "send failed");
        // State updated only after the external call: the bug.
        balances[msg.sender] = 0;
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }
}
