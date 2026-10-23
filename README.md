# defi-poc-lab

Working proof-of-concepts for classic DeFi vulnerability patterns — the ones that keep costing protocols real money.

Every pattern ships as a pair: a vulnerable contract small enough to read in one sitting, a test that runs the actual attack against it, and a fixed version where the same test script walks away with nothing. No fork tests, no RPC keys, nothing to configure — if you have Foundry, `forge test` just runs.

```bash
forge test
```

## What's in here

**Share inflation (first-depositor / donation attack)**
`src/vault-inflation/`
A vault that prices shares off its raw token balance. Deposit 1 wei, donate a pile of tokens directly to the vault address, and the next depositor's shares round down to zero — then redeem your single share for everything. This is the ERC-4626 inflation pattern. The fix prices shares off internal accounting with a virtual offset, so donations stop moving the price.

**Reentrancy**
`src/reentrancy/`
The DAO pattern, unchanged since 2016 because it still works: a bank that sends Ether before settling the sender's balance. The fixed version settles first, and the attack contract gets back exactly what it put in. Cream Finance lost $130M to a variant of this in 2021, five years after The DAO supposedly taught everyone the lesson.

**Spot-price oracle manipulation**
`src/oracle-manipulation/`
A lending market that prices collateral off a DEX pool's spot price. One large swap bends the price ~3.6x, and the market lends against the bent price like it's real. The fix reads a time-weighted average instead — the pump still happens, the price the market believes barely moves. Harvest, Cheese Bank, and dozens of smaller markets learned this one the expensive way.

## Why this exists

I hunt bug bounties in DeFi. Most real findings aren't exotic — they're these three shapes wearing new clothes. Keeping minimal, runnable versions of them is how I sanity-check my instincts before I go read a real protocol's code: if I can't reproduce the pattern here, I don't understand it well enough to claim it there.

Each contract is deliberately minimal. These are teaching and testing tools, not audited code — don't deploy any of it with real funds.

## Adding a pattern

New entries follow the same shape: `Vulnerable*` contract, `Fixed*` contract, one test file that attacks both, and a short comment in the vulnerable contract naming the real-world incident the pattern comes from.
