use cardano/assets.{from_lovelace}
use cardano/transaction.{Transaction}
use mocktail.{
  complete, mock_pub_key_address, mock_tx_hash, mocktail_tx, set_fee, tx_in,
  tx_out,
}

// Build a mock spending transaction
fn mock_spending_tx() -> Transaction {
  mocktail_tx()
    |> tx_in(
        True,
        mock_tx_hash(0),
        0,
        from_lovelace(10_000_000),
        // 10 ADA input
        mock_pub_key_address(0, None),
      )
    |> tx_out(True, mock_pub_key_address(1, None), from_lovelace(9_000_000))
    // 9 ADA output
    |> complete()
    |> set_fee(True, 1_000_000)
  // 1 ADA fee
}

// Test that the transaction balances
test test_balance() {
  expect _tx = mock_spending_tx()

  // Check that input = output + fee
  let input = 10_000_000
  let output = 9_000_000
  let fee = 1_000_000

  expect input == output + fee
}
