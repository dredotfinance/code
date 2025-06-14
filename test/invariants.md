# Invariants

Here are a list of invariants the tests go through. Some of these tests are tested using foundry and some via halmos.

- **Treasury Collateralization Invariants**:

  - Total reserves must always be greater than or equal to total supply (excluding unbacked supply)
  - The treasury must be over-collateralized at all times
  - When depositing tokens, the value of reserves must increase by at least the amount of tokens minted
  - When withdrawing tokens, the value of reserves must decrease by at least the amount of tokens burned

- **Token Supply Invariants**:

  - Unbacked supply cannot exceed total supply
  - Total supply = Circulating supply + Unbacked supply
  - When minting new tokens, there must be sufficient excess reserves
  - When burning tokens, the amount burned cannot exceed the balance

- **Price Oracle Invariants**:

  - RZR token must always have 18 decimals
  - Token prices must be greater than 0
  - Floor price can only increase, never decrease
  - New floor price must be less than 2x current floor price

- **Staking Invariants**:

  - Harberger tax rate must be less than or equal to 100% (BASIS_POINTS)
  - Resell fee rate must be less than or equal to 100% (BASIS_POINTS)
  - Withdraw cooldown period must be greater than 0
  - Reward cooldown period must be greater than 0
  - Total staked amount must equal sum of all position amounts

- **Bond Depository Invariants**:

  - Bond price must be greater than 0
  - Bond price must be less than or equal to 1 (100%)
  - Bond payout must be greater than 0
  - Bond vesting period must be greater than 0
  - Bond max payout must be greater than 0

- **Access Control Invariants**: Only authorized roles can perform specific actions:

  - Governor: Can update oracles, enable/disable tokens, set parameters
  - Policy: Can mint tokens, set reserve fees
  - Reserve Manager: Can withdraw tokens, manage reserves
  - Reserve Depositor: Can deposit tokens
  - Guardian: Can pause/unpause, disable tokens
  - Executor: Can sync reserves, execute burns
  - Bond Manager: Can manage bonds

- **Rebase Controller Invariants**:

  - Target operations percentage must be reasonable (ideally 10%)
  - Minimum floor percentage must be reasonable (ideally 15%)
  - Maximum floor percentage must be reasonable (ideally 50%)
  - Floor slope must be reasonable (ideally 50%)
  - Epoch must be 8 hours

- **Referral System Invariants**:

  - Referral codes must be unique
  - Referrer codes must be unique
  - Referral rewards must be properly distributed
  - Merkle proofs must be valid

- **Bond sales must maintain treasury backing ratio:**

  - When a bond is sold, the treasury must receive sufficient collateral
  - The amount of RZR tokens minted for the bond must not exceed the value of collateral received
  - Bond sales should not reduce the treasury's backing ratio below the minimum required level. It should in fact increase the backing ratio.
  - The total value of bonds sold should not exceed the treasury's excess reserves

- **Bond pricing and payout invariants:**

  - Bond price must be greater than 0
  - Bond price must be less than or equal to 1 (100%)
  - Bond payout must be greater than 0
  - Bond vesting period must be greater than 0
  - Bond max payout must be greater than 0
  - Bond price should reflect the current backing ratio of the treasury

- **Rebase operations must maintain treasury backing ratio:**

  - Rebase operations should never reduce the treasury's backing ratio below 1
  - The amount of tokens minted/burned during rebase must be proportional to the change in backing ratio

- **Floor price and rebase relationship:**

  - Floor price updates during rebase must maintain the treasury's backing ratio
  - New floor price must be supported by the treasury's collateral
  - Rebase operations should not create unbacked supply

- **Rebase timing and parameters:**

  - Target operations percentage must be reasonable (ideally 10%)
  - Minimum floor percentage must be reasonable (ideally 15%)
  - Maximum floor percentage must be reasonable (ideally 50%)
  - Floor slope must be reasonable (ideally 50%)
  - Epoch must be 8 hours
  - Rebase operations must be properly spaced according to the epoch
