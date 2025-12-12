// validators/assignment_103.ak

use aiken/collection/dict
use cardano/assets.{from_asset, merge, tokens}
use cardano/transaction.{Transaction, placeholder}
use mocktail.{mock_policy_id}

// Mock token names for our two different NFTs
fn art_nft_token_name() -> ByteArray {
  "CryptoArt#001"
}

fn membership_nft_token_name() -> ByteArray {
  "GoldMember#123"
}

/// Create a transaction that mints two different NFTs
/// NFT 1: Art NFT from policy 0 
/// NFT 2: Membership NFT from policy 1
fn mock_dual_nft_minting_tx() -> Transaction {
  // Create mint value for first NFT (Art NFT)
  let art_nft_mint = from_asset(mock_policy_id(0), art_nft_token_name(), 1)
  // Create mint value for second NFT (Membership NFT)
  let membership_nft_mint =
    from_asset(mock_policy_id(1), membership_nft_token_name(), 1)
  // Combine both mints into a single mint field
  let total_mint = merge(art_nft_mint, membership_nft_mint)
  Transaction { ..placeholder, mint: total_mint }
}

// PASSING TEST - Should succeed
test dual_nft_minting_success() {
  let tx = mock_dual_nft_minting_tx()
  // Test by checking if we can extract the expected tokens
  let art_token_dict = tokens(tx.mint, mock_policy_id(0))
  let membership_token_dict = tokens(tx.mint, mock_policy_id(1))
  // Verify Art NFT exists with correct quantity
  expect Some(art_quantity) = dict.get(art_token_dict, art_nft_token_name())
  let art_correct = art_quantity == 1
  // Verify Membership NFT exists with correct quantity
  expect Some(membership_quantity) =
    dict.get(membership_token_dict, membership_nft_token_name())
  let membership_correct = membership_quantity == 1
  art_correct && membership_correct
}

// FAILING TEST - Should fail because we mint wrong quantity
fn mock_wrong_quantity_tx() -> Transaction {
  // Mint 2 art NFTs instead of 1 (breaks NFT uniqueness!)
  let wrong_art_nft = from_asset(mock_policy_id(0), art_nft_token_name(), 2)
  let membership_nft =
    from_asset(mock_policy_id(1), membership_nft_token_name(), 1)
  Transaction { ..placeholder, mint: merge(wrong_art_nft, membership_nft) }
}

test dual_nft_wrong_quantity_fails() {
  let tx = mock_wrong_quantity_tx()
  // Check that art NFT has wrong quantity (should be 1, but is 2)
  let art_token_dict = tokens(tx.mint, mock_policy_id(0))
  expect Some(art_quantity) = dict.get(art_token_dict, art_nft_token_name())
  // Test expects failure - quantity should NOT be 1 (it's 2)
  art_quantity != 1
}
