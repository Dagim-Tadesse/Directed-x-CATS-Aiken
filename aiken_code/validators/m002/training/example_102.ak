use cardano/transaction.{OutputReference, Transaction, placeholder}
use mocktail.{mock_utxo_ref}

// Custom Datum Type - represents the "lock configuration"
pub type CustomDatum {
  SecretMessage { secret: ByteArray, owner: ByteArray, amount_locked: Int }
  PublicInfo { public_message: ByteArray, created_at: Int }
  EmptyDatum
}

// Custom Redeemer Type - represents the "key" to unlock
pub type CustomRedeemer {
  UnlockWithSecret { provided_secret: ByteArray, signature_required: Bool }
  PublicAccess { reason: ByteArray }
  AdminOverride { admin_signature: ByteArray }
  EmergencyUnlock
}

validator custom_spending_validator {
  spend(
    datum_opt: Option<CustomDatum>,
    redeemer: CustomRedeemer,
    _input: OutputReference,
    _tx: Transaction,
  ) {
    // Handle the case where no datum is provided
    when datum_opt is {
      None -> False
      // Reject if no datum provided
      Some(datum) ->
        // Now validate based on both datum and redeemer types
        when datum is {
          SecretMessage { secret, owner: _, amount_locked } ->
            when redeemer is {
              UnlockWithSecret { provided_secret, signature_required: _ } ->
                // Secret must match and amount must be positive
                provided_secret == secret && amount_locked > 0
              AdminOverride { admin_signature: _ } ->
                // Admin can unlock if amount is reasonable
                amount_locked <= 1000000
              // Max 1 ADA
              EmergencyUnlock ->
                // Emergency unlock only for small amounts
                amount_locked <= 100000
              // Max 0.1 ADA
              _ -> False
            }
          // Other redeemers don't work
          PublicInfo { public_message: _, created_at } ->
            when redeemer is {
              PublicAccess { reason } ->
                // Must provide a reason and data must be old enough
                reason != "" && created_at < 1000000
              AdminOverride { admin_signature: _ } -> True
              _ -> False
            }
          EmptyDatum ->
            when redeemer is {
              EmergencyUnlock -> True
              PublicAccess { reason: _ } -> True
              _ -> False
            }
        }
    }
  }

  else(_) {
    fail
  }
}

// ===== TESTS =====

/// Test 1: SUCCESS - Correct secret should unlock
test test_correct_secret_unlocks() {
  let datum =
    Some(SecretMessage { secret: "ABC", owner: "alice", amount_locked: 500000 })
  let redeemer =
    UnlockWithSecret { provided_secret: "ABC", signature_required: True }
  custom_spending_validator.spend(
    datum,
    redeemer,
    mock_utxo_ref(0, 0),
    placeholder,
  )
}

/// Test 2: FAILURE - Wrong secret should fail
test test_wrong_secret_fails() {
  let datum =
    Some(
      SecretMessage {
        secret: "correct_password",
        owner: "alice",
        amount_locked: 500000,
      },
    )
  let redeemer =
    UnlockWithSecret {
      provided_secret: "wrong_password",
      signature_required: True,
    }
  !custom_spending_validator.spend(
    datum,
    redeemer,
    mock_utxo_ref(0, 0),
    placeholder,
  )
}

/// Test 3: FAILURE - No datum should fail
test test_no_datum_fails() {
  let datum = None
  let redeemer = EmergencyUnlock
  !custom_spending_validator.spend(
    datum,
    redeemer,
    mock_utxo_ref(0, 0),
    placeholder,
  )
}
