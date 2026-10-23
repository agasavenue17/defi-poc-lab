// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal cheatcode surface (no forge-std dependency on purpose —
///         this repo builds anywhere `forge` runs).
interface Vm {
    function deal(address who, uint256 amount) external;
    function prank(address who) external;
}

/// @notice Shared test plumbing: assertions and actor forwarding.
abstract contract TestHelper {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(uint256 a, uint256 b, string memory what) internal pure {
        require(a == b, string.concat("assertEq failed: ", what));
    }

    function assertGt(uint256 a, uint256 b, string memory what) internal pure {
        require(a > b, string.concat("assertGt failed: ", what));
    }

    function assertTrue(bool cond, string memory what) internal pure {
        require(cond, string.concat("assertTrue failed: ", what));
    }
}
