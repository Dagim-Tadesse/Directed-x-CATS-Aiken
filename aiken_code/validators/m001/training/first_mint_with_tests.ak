use aiken/collection/dict
use aiken/collection/list
use aiken/primitive/bytearray
// ============================================================================
// FIRST MINTING POLICY WITH TESTS - Simple NFT Collection Minter
// ============================================================================
// This file contains the same NFT minting policy as first_mint.ak, but now
// includes a comprehensive test suite. Testing minting policies is critical
// because once tokens are minted, they exist permanently on the blockchain.
// Bugs in minting logic could allow unlimited token creation or prevent
// legitimate minting.
//
// Real-world importance: Many NFT projects have suffered from exploits where
// attackers minted more tokens than intended, devaluing entire collections.
// Proper testing prevents such disasters.
// ============================================================================

use cardano/assets.{PolicyId, from_asset}
use cardano/transaction.{Transaction, placeholder}

// ----------------------------------------------------------------------------
// REDEEMER - Minting action parameters
// ----------------------------------------------------------------------------
pub type MintRedeemer {
  token_name: ByteArray,
  quantity: Int,
}

// ----------------------------------------------------------------------------
// VALIDATOR - Minting policy logic
// ----------------------------------------------------------------------------
validator nft_collection {
  mint(redeemer: MintRedeemer, policy_id: PolicyId, tx: Transaction) {
    // Extract the transaction details we need to validate
    let signatories = tx.extra_signatories
    // Define the artist's public key hash who is authorized to mint
    // In a real deployment, this would be Sarah's actual public key hash
    // Format: ByteArray representing the verification key hash
    let authorized_minter: ByteArray = #"abcd1234"
    // Placeholder - replace with real key hash
    // Define the maximum supply for the collection
    let max_supply = 100
    // Get the token being minted from the redeemer
    let token_name = redeemer.token_name
    let mint_quantity = redeemer.quantity
    // ------------------------------------------------------------------
    // VALIDATION RULE 1: Only authorized minter can mint
    // ------------------------------------------------------------------
    // Check that the transaction is signed by the authorized artist
    // This prevents random people from minting NFTs in Sarah's collection
    let authorized = list.has(signatories, authorized_minter)
    // ------------------------------------------------------------------
    // VALIDATION RULE 2: Minting quantity rules
    // ------------------------------------------------------------------
    // For NFTs (Non-Fungible Tokens), we should only mint exactly 1 token
    // at a time. This ensures each token is unique and non-fungible.
    //
    // If quantity is positive: we're minting (creating new tokens)
    // If quantity is negative: we're burning (destroying tokens)
    // If quantity is zero: invalid operation
    let valid_quantity =
      if mint_quantity > 0 {
        // Minting: must be exactly 1 for NFTs
        mint_quantity == 1
      } else if mint_quantity < 0 {
        // Burning: can burn tokens (e.g., for cleanup or mistakes)
        // For NFTs, we'd typically burn exactly -1 token at a time
        mint_quantity == -1
      } else {
        // Quantity of 0 makes no sense - reject
        False
      }
    // ------------------------------------------------------------------
    // VALIDATION RULE 3: Check total supply doesn't exceed maximum
    // ------------------------------------------------------------------
    // Calculate how many tokens with this policy_id exist in the transaction
    // This checks if we'd exceed the max supply with this minting operation
    // Get the tokens being minted in this transaction for this policy
    let tokens_list =
      tx.mint
        |> assets.tokens(policy_id)
        |> dict.to_pairs()
    // Check that exactly one token is being minted/burned
    let within_supply_cap =
      when tokens_list is {
        [Pair(_asset_name, tokens_in_tx)] ->
          // Validate the token count is within bounds
          tokens_in_tx <= max_supply && tokens_in_tx >= -max_supply
        // If the list is empty or has multiple entries, reject
        _ -> False
      }
    // ------------------------------------------------------------------
    // VALIDATION RULE 4: Token name uniqueness
    // ------------------------------------------------------------------
    // Each NFT should have a unique name within the collection
    // Token names should follow a pattern, e.g., "ArtPiece001", "ArtPiece002"
    // Minimum length prevents empty or very short names
    let valid_token_name = bytearray.length(token_name) >= 1
    // ------------------------------------------------------------------
    // FINAL DECISION: All conditions must be true
    // ------------------------------------------------------------------
    // The transaction is only approved if ALL security checks pass
    authorized && valid_quantity && within_supply_cap && valid_token_name
  }

  else(_) {
    fail
  }
}

// ============================================================================
// TEST SUITE
// ============================================================================

// ----------------------------------------------------------------------------
// HELPER FUNCTIONS FOR TESTS
// ----------------------------------------------------------------------------

// The authorized minter (Sarah the artist)
fn authorized_minter() -> ByteArray {
  #"abcd1234"
}

// An unauthorized user trying to mint
fn unauthorized_user() -> ByteArray {
  #"deadbeef"
}

// Sample policy ID for the NFT collection (valid hex)
fn sample_policy_id() -> PolicyId {
  #"a0b1c2d3e4f56789a0b1c2d3e4f56789a0b1c2d3e4f56789a0b1c2d3"
}

// Create a test transaction for minting operations
fn sample_mint_context(
  policy_id: PolicyId,
  token_name: ByteArray,
  quantity: Int,
  signatories: List<ByteArray>,
) -> Transaction {
  Transaction {
    ..placeholder,
    extra_signatories: signatories,
    mint: from_asset(policy_id, token_name, quantity),
  }
}

// ----------------------------------------------------------------------------
// TEST 1: Authorized minter can mint valid NFT
// ----------------------------------------------------------------------------
// This tests the happy path where Sarah (authorized minter) mints a single
// NFT with a valid token name.
test authorized_minter_can_mint() {
  // SETUP
  let policy_id = sample_policy_id()
  let token_name = #"4172745069656365303031"
  // "ArtPiece001" in hex
  let redeemer = MintRedeemer { token_name, quantity: 1 }
  let tx = sample_mint_context(policy_id, token_name, 1, [authorized_minter()])
  // Sarah signs
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should succeed because:
  // 1. Signed by authorized minter
  // 2. Quantity is exactly 1 (valid for NFT)
  // 3. Token name is valid (non-empty)
  // 4. Within supply cap
  result == True
}

// ----------------------------------------------------------------------------
// TEST 2: Unauthorized user cannot mint
// ----------------------------------------------------------------------------
// This tests that a random person cannot mint NFTs in Sarah's collection.
// This is a critical security test.
test unauthorized_user_cannot_mint() {
  // SETUP
  let policy_id = sample_policy_id()
  let token_name = #"4172745069656365303031"
  let redeemer = MintRedeemer { token_name, quantity: 1 }
  let tx = sample_mint_context(policy_id, token_name, 1, [unauthorized_user()])
  // Random person signs (not Sarah)
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should fail because:
  // 1. NOT signed by authorized minter
  // 2. Even though quantity and token name are valid
  result == False
}

// ----------------------------------------------------------------------------
// TEST 3: Cannot mint quantity greater than 1
// ----------------------------------------------------------------------------
// This tests that we cannot mint multiple copies of an NFT at once.
// NFTs must be unique (quantity = 1).
test cannot_mint_multiple_copies() {
  // SETUP
  let policy_id = sample_policy_id()
  let token_name = #"4172745069656365303031"
  let redeemer = MintRedeemer { token_name, quantity: 5 }
  // Trying to mint 5 copies!
  let tx = sample_mint_context(policy_id, token_name, 5, [authorized_minter()])
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should fail because:
  // 1. Quantity is 5, not 1
  // 2. NFTs must be minted one at a time
  result == False
}

// ----------------------------------------------------------------------------
// TEST 4: Cannot mint with quantity of 0
// ----------------------------------------------------------------------------
// This tests that minting zero tokens is invalid (doesn't make sense).
test cannot_mint_zero() {
  // SETUP
  let policy_id = sample_policy_id()
  let token_name = #"4172745069656365303031"
  let redeemer = MintRedeemer { token_name, quantity: 0 }
  // Zero quantity
  let tx = sample_mint_context(policy_id, token_name, 0, [authorized_minter()])
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should fail because:
  // 1. Quantity is 0 (invalid)
  // 2. Must be 1 (mint) or -1 (burn)
  result == False
}

// ----------------------------------------------------------------------------
// TEST 5: Authorized minter can burn tokens
// ----------------------------------------------------------------------------
// This tests that Sarah can burn (destroy) an NFT if needed (e.g., to fix
// a mistake or remove a defective NFT).
test authorized_minter_can_burn() {
  // SETUP
  let policy_id = sample_policy_id()
  let token_name = #"4172745069656365303031"
  let redeemer = MintRedeemer { token_name, quantity: -1 }
  // Negative = burn
  let tx = sample_mint_context(policy_id, token_name, -1, [authorized_minter()])
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should succeed because:
  // 1. Signed by authorized minter
  // 2. Quantity is exactly -1 (valid for burning)
  // 3. Token name is valid
  result == True
}

// ----------------------------------------------------------------------------
// TEST 6: Cannot burn multiple tokens at once
// ----------------------------------------------------------------------------
// This tests that burning must be done one token at a time (quantity = -1).
test cannot_burn_multiple() {
  // SETUP
  let policy_id = sample_policy_id()
  let token_name = #"4172745069656365303031"
  let redeemer = MintRedeemer { token_name, quantity: -5 }
  // Trying to burn 5 at once
  let tx = sample_mint_context(policy_id, token_name, -5, [authorized_minter()])
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should fail because:
  // 1. Quantity is -5, not -1
  // 2. Must burn one at a time
  result == False
}

// ----------------------------------------------------------------------------
// TEST 7: Unauthorized user cannot burn
// ----------------------------------------------------------------------------
// This tests that random users cannot burn NFTs from the collection.
// Only the authorized minter can burn.
test unauthorized_user_cannot_burn() {
  // SETUP
  let policy_id = sample_policy_id()
  let token_name = #"4172745069656365303031"
  let redeemer = MintRedeemer { token_name, quantity: -1 }
  let tx = sample_mint_context(policy_id, token_name, -1, [unauthorized_user()])
  // Not Sarah
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should fail because:
  // 1. NOT signed by authorized minter
  result == False
}

// ----------------------------------------------------------------------------
// TEST 8: Cannot mint with empty token name
// ----------------------------------------------------------------------------
// This tests that token names must be at least 1 byte long.
// Empty token names are not allowed.
test cannot_mint_empty_token_name() {
  // SETUP
  let policy_id = sample_policy_id()
  let token_name = ""
  // Empty ByteArray (using string syntax)
  let redeemer = MintRedeemer { token_name, quantity: 1 }
  let tx = sample_mint_context(policy_id, token_name, 1, [authorized_minter()])
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should fail because:
  // 1. Token name is empty (length = 0)
  // 2. Minimum length is 1 byte
  result == False
}

// ----------------------------------------------------------------------------
// TEST 9: Can mint with single-byte token name
// ----------------------------------------------------------------------------
// This tests the boundary condition where token name is exactly 1 byte.
// This should be valid (minimum allowed length).
test can_mint_single_byte_token_name() {
  // SETUP
  let policy_id = sample_policy_id()
  let token_name = #"41"
  // Just "A" in hex (1 byte)
  let redeemer = MintRedeemer { token_name, quantity: 1 }
  let tx = sample_mint_context(policy_id, token_name, 1, [authorized_minter()])
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should succeed because:
  // 1. Token name is 1 byte (minimum valid length)
  // 2. All other conditions are met
  result == True
}

// ----------------------------------------------------------------------------
// TEST 10: Can mint with long token name
// ----------------------------------------------------------------------------
// This tests that longer token names (within reasonable limits) work fine.
test can_mint_long_token_name() {
  // SETUP
  let policy_id = sample_policy_id()
  // "ArtPiece001_Limited_Edition_Collection_2024" in hex (long but valid)
  let token_name =
    #"41727450696563653030315f4c696d697465645f45646974696f6e5f436f6c6c656374696f6e5f32303234"
  let redeemer = MintRedeemer { token_name, quantity: 1 }
  let tx = sample_mint_context(policy_id, token_name, 1, [authorized_minter()])
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should succeed because:
  // 1. Token name is valid (> 1 byte)
  // 2. All other conditions are met
  result == True
}

// ----------------------------------------------------------------------------
// TEST 11: Minting with no signatures fails
// ----------------------------------------------------------------------------
// This tests that transactions with no signatures at all are rejected.
test minting_with_no_signatures_fails() {
  // SETUP
  let policy_id = sample_policy_id()
  let token_name = #"4172745069656365303031"
  let redeemer = MintRedeemer { token_name, quantity: 1 }
  let tx = sample_mint_context(policy_id, token_name, 1, [])
  // No signatures!
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should fail because:
  // 1. No signatures provided
  // 2. Authorized minter must sign
  result == False
}

// ----------------------------------------------------------------------------
// TEST 12: Extra signatures don't break minting
// ----------------------------------------------------------------------------
// This tests that having additional signatures (beyond the authorized minter)
// doesn't prevent valid minting operations.
test extra_signatures_dont_break_minting() {
  // SETUP
  let policy_id = sample_policy_id()
  let token_name = #"4172745069656365303031"
  let redeemer = MintRedeemer { token_name, quantity: 1 }
  let tx =
    sample_mint_context(
      policy_id,
      token_name,
      1,
      [authorized_minter(), unauthorized_user()],
    )
  // Multiple signatures
  // ACTION
  let result = nft_collection.mint(redeemer, policy_id, tx)
  // ASSERT
  // Should succeed because:
  // 1. Authorized minter signed (that's what matters)
  // 2. Extra signatures are allowed
  result == True
}
// ============================================================================
// RUNNING THE TESTS
// ============================================================================
//
// To run these tests, use the Aiken CLI:
//
//   aiken check
//
// Example output:
//   ✓ authorized_minter_can_mint
//   ✓ unauthorized_user_cannot_mint
//   ✓ cannot_mint_multiple_copies
//   ✓ cannot_mint_zero
//   ✓ authorized_minter_can_burn
//   ✓ cannot_burn_multiple
//   ✓ unauthorized_user_cannot_burn
//   ✓ cannot_mint_empty_token_name
//   ✓ can_mint_single_byte_token_name
//   ✓ can_mint_long_token_name
//   ✓ minting_with_no_signatures_fails
//   ✓ extra_signatures_dont_break_minting
//
//   12 tests passed, 0 failed
//
// ============================================================================
// TEST COVERAGE ANALYSIS
// ============================================================================
//
// Our test suite covers:
//
// ✓ Happy path minting (authorized user mints 1 NFT)
// ✓ Happy path burning (authorized user burns 1 NFT)
// ✓ Authorization checks (unauthorized users rejected)
// ✓ Quantity validation (must be 1 or -1)
// ✓ Token name validation (empty vs valid names)
// ✓ Boundary conditions (minimum/maximum token name lengths)
// ✓ Edge cases (no signatures, extra signatures)
//
// What's NOT covered (would add in production):
// ✗ Supply cap enforcement across multiple transactions
// ✗ Duplicate token name prevention
// ✗ Time-based restrictions (minting windows)
// ✗ Integration with metadata standards (CIP-25)
// ✗ Royalty information (CIP-27)
//
// ============================================================================
// BEST PRACTICES FOR MINTING POLICY TESTS
// ============================================================================
//
// 1. TEST AUTHORIZATION THOROUGHLY: Minting policies are often exploited
//    through authorization bypasses. Test every combination of authorized
//    and unauthorized users.
//
// 2. TEST QUANTITY BOUNDS: Test positive quantities (minting), negative
//    quantities (burning), zero, and out-of-bounds values.
//
// 3. TEST TOKEN NAME EDGE CASES: Empty strings, single characters, maximum
//    length names, special characters, etc.
//
// 4. TEST SIGNATURE VARIATIONS: No signatures, correct signatures, incorrect
//    signatures, multiple signatures.
//
// 5. THINK LIKE AN ATTACKER: What would you try if you wanted to exploit
//    this minting policy? Test those attack vectors.
//
// 6. TEST REALISTIC SCENARIOS: Use actual hex-encoded token names, realistic
//    policy IDs, and proper signature formats.
//
// 7. VERIFY BOTH MINTING AND BURNING: If your policy allows burning, test
//    those paths just as thoroughly as minting.
//
// ============================================================================
// COMMON MINTING EXPLOITS TO TEST AGAINST
// ============================================================================
//
// 1. UNAUTHORIZED MINTING: Attacker tries to mint without authorization
//    → Our Test 2 covers this
//
// 2. OVER-MINTING: Attacker tries to mint more than the supply cap
//    → Our Test 3 partially covers this (needs improvement)
//
// 3. DUPLICATE MINTING: Attacker tries to mint the same token name twice
//    → Not covered in this simplified version (needs tracking)
//
// 4. ZERO/NEGATIVE MINTING: Attacker tries invalid quantities
//    → Our Tests 4, 6 cover this
//
// 5. SIGNATURE FORGERY: Attacker tries to forge authorization
//    → Handled by Cardano's cryptography, but we test signature checks
//
// 6. FRONT-RUNNING: Attacker sees a pending mint and tries to mint first
//    → Not testable at validator level (handled by blockchain ordering)
//
// ============================================================================
