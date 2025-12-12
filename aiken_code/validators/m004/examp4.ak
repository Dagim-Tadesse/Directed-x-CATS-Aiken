// =============================================================================
// Module M004 Workshop Examples
// Advanced Input Validation
// =============================================================================

use aiken/collection/list
use cardano/address.{Address, VerificationKey}
use cardano/assets.{
  PolicyId, add, from_lovelace, lovelace_of, merge, quantity_of, zero,
}
use cardano/transaction.{
  Input, Output, OutputReference, Transaction, find_input,
}
use cocktail.{inputs_at, outputs_at}
use mocktail.{
  complete, mock_policy_id, mock_pub_key_address, mock_script_address,
  mock_tx_hash, mock_utxo_ref, mocktail_tx, tx_in, tx_out,
}

// -----------------------------------------------------------------------------
// Example 1: Address Filtering (Exercise 1)
// Demonstrates: Finding and filtering inputs by address
// -----------------------------------------------------------------------------

validator address_filter_validator {
  spend(
    _datum: Option<Data>,
    _redeemer: Data,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    // Find our own input
    expect Some(own_input) = find_input(self.inputs, own_ref)
    let our_address = own_input.output.address

    // Filter all inputs at our script address
    let script_inputs = inputs_at(self.inputs, our_address)

    // Ensure exactly 1 input at our address
    when script_inputs is {
      [_single] -> True
      _ -> False
    }
  }

  else(_) {
    fail
  }
}

// Tests for address filtering
test test_address_filter_single_input_passes() {
  let script_addr = mock_script_address(0, None)
  let tx =
    mocktail_tx()
      |> tx_in(True, mock_tx_hash(0), 0, from_lovelace(10_000_000), script_addr)
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(5_000_000),
          mock_pub_key_address(0, None),
        )
      // Wallet input
      |> complete()

  address_filter_validator.spend(None, Void, mock_utxo_ref(0, 0), tx)
}

test test_address_filter_multiple_inputs_fails() fail {
  let script_addr = mock_script_address(0, None)
  let tx =
    mocktail_tx()
      |> tx_in(True, mock_tx_hash(0), 0, from_lovelace(10_000_000), script_addr)
      |> tx_in(True, mock_tx_hash(0), 1, from_lovelace(10_000_000), script_addr)
      // Second script input!
      |> complete()

  address_filter_validator.spend(None, Void, mock_utxo_ref(0, 0), tx)
}

test test_address_filter_zero_script_inputs_passes() {
  // This test should pass because we're validating input at index 0
  // which is the wallet input - the validator will find it but
  // when filtering by that wallet address, only 1 input exists
  let wallet_addr = mock_pub_key_address(0, None)
  let tx =
    mocktail_tx()
      |> tx_in(True, mock_tx_hash(0), 0, from_lovelace(10_000_000), wallet_addr)
      |> complete()

  address_filter_validator.spend(None, Void, mock_utxo_ref(0, 0), tx)
}

// -----------------------------------------------------------------------------
// Example 2: Prevent Double-Satisfaction (Exercise 2)
// Demonstrates: Critical security pattern
// -----------------------------------------------------------------------------

pub type PaymentDatum {
  beneficiary: ByteArray,
  price: Int,
}

pub type PaymentRedeemer {
  Pay
}

// ✅ SECURE VERSION - Prevents double-satisfaction
validator secure_payment {
  spend(
    datum: Option<PaymentDatum>,
    redeemer: PaymentRedeemer,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(payment_datum) = datum
    let Pay = redeemer

    // CRITICAL: Ensure only ONE input from our validator
    expect Some(own_input) = find_input(self.inputs, own_ref)
    let our_address = own_input.output.address
    let script_inputs = inputs_at(self.inputs, our_address)
    expect [_single] = script_inputs

    // Now safe to check outputs
    let beneficiary_addr =
      Address {
        payment_credential: VerificationKey(payment_datum.beneficiary),
        stake_credential: None,
      }

    let outputs_to_beneficiary = outputs_at(self.outputs, beneficiary_addr)

    let total_paid =
      list.foldl(
        outputs_to_beneficiary,
        zero,
        fn(output, total) { merge(output.value, total) },
      )

    lovelace_of(total_paid) >= payment_datum.price
  }

  else(_) {
    fail
  }
}

// Tests for secure payment
test test_secure_payment_single_input_passes() {
  let datum = Some(PaymentDatum { beneficiary: #"aabbcc", price: 5_000_000 })
  let script_addr = mock_script_address(0, None)
  // Create beneficiary address that matches the datum
  let beneficiary_addr =
    Address {
      payment_credential: VerificationKey(#"aabbcc"),
      stake_credential: None,
    }

  let tx =
    mocktail_tx()
      |> tx_in(True, mock_tx_hash(0), 0, from_lovelace(10_000_000), script_addr)
      |> tx_out(True, beneficiary_addr, from_lovelace(5_000_000))
      |> complete()

  secure_payment.spend(datum, Pay, mock_utxo_ref(0, 0), tx)
}

test test_secure_payment_prevents_double_satisfaction() fail {
  let datum1 = Some(PaymentDatum { beneficiary: #"aabbcc", price: 5_000_000 })
  let script_addr = mock_script_address(0, None)
  let beneficiary_addr =
    Address {
      payment_credential: VerificationKey(#"aabbcc"),
      stake_credential: None,
    }

  let tx =
    mocktail_tx()
      |> tx_in(True, mock_tx_hash(0), 0, from_lovelace(20_000_000), script_addr)
      |> tx_in(True, mock_tx_hash(0), 1, from_lovelace(20_000_000), script_addr)
      // Two script inputs!
      |> tx_out(True, beneficiary_addr, from_lovelace(10_000_000))
      |> complete()

  // Secure validator detects multiple script inputs and fails!
  secure_payment.spend(datum1, Pay, mock_utxo_ref(0, 0), tx)
}

test test_secure_payment_insufficient_payment_fails() fail {
  let datum = Some(PaymentDatum { beneficiary: #"aabbcc", price: 5_000_000 })
  let script_addr = mock_script_address(0, None)
  let beneficiary_addr =
    Address {
      payment_credential: VerificationKey(#"aabbcc"),
      stake_credential: None,
    }

  let tx =
    mocktail_tx()
      |> tx_in(True, mock_tx_hash(0), 0, from_lovelace(10_000_000), script_addr)
      |> tx_out(True, beneficiary_addr, from_lovelace(2_000_000))
      // Only 2 ADA, needs 5!
      |> complete()

  secure_payment.spend(datum, Pay, mock_utxo_ref(0, 0), tx)
}

// -----------------------------------------------------------------------------
// Example 3: Value Validation (Exercise 3)
// Demonstrates: Checking ADA and token amounts in inputs
// -----------------------------------------------------------------------------

pub type ValueRequirements {
  minimum_lovelace: Int,
  required_token_policy: PolicyId,
  required_token_name: ByteArray,
  minimum_token_amount: Int,
}

validator value_validator {
  spend(
    datum: Option<ValueRequirements>,
    _redeemer: Data,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(requirements) = datum

    // Get our input
    expect Some(own_input) = find_input(self.inputs, own_ref)
    let input_value = own_input.output.value

    // Check 1: Minimum lovelace
    let has_minimum_ada =
      lovelace_of(input_value) >= requirements.minimum_lovelace

    // Check 2: Minimum token quantity
    let token_qty =
      quantity_of(
        input_value,
        requirements.required_token_policy,
        requirements.required_token_name,
      )
    let has_minimum_tokens = token_qty >= requirements.minimum_token_amount

    // Both checks must pass
    has_minimum_ada && has_minimum_tokens
  }

  else(_) {
    fail
  }
}

// Tests for value validation
test test_value_sufficient_ada_and_tokens_passes() {
  let policy = mock_policy_id(0)
  let token_name = #"4d79546f6b656e"

  // "MyToken"
  let datum =
    Some(
      ValueRequirements {
        minimum_lovelace: 5_000_000,
        required_token_policy: policy,
        required_token_name: token_name,
        minimum_token_amount: 100,
      },
    )

  let value =
    zero
      |> add(#"", #"", 10_000_000)
      // 10 ADA
      |> add(policy, token_name, 150)

  // 150 tokens
  let script_addr = mock_script_address(0, None)
  let tx =
    mocktail_tx()
      |> tx_in(True, mock_tx_hash(0), 0, value, script_addr)
      |> complete()

  value_validator.spend(datum, Void, mock_utxo_ref(0, 0), tx)
}

test test_value_insufficient_ada_fails() fail {
  let policy = mock_policy_id(0)
  let token_name = #"4d79546f6b656e"

  let datum =
    Some(
      ValueRequirements {
        minimum_lovelace: 5_000_000,
        required_token_policy: policy,
        required_token_name: token_name,
        minimum_token_amount: 100,
      },
    )

  let value =
    zero
      |> add(#"", #"", 2_000_000)
      // Only 2 ADA!
      |> add(policy, token_name, 150)

  let script_addr = mock_script_address(0, None)
  let tx =
    mocktail_tx()
      |> tx_in(True, mock_tx_hash(0), 0, value, script_addr)
      |> complete()

  value_validator.spend(datum, Void, mock_utxo_ref(0, 0), tx)
}

test test_value_insufficient_tokens_fails() fail {
  let policy = mock_policy_id(0)
  let token_name = #"4d79546f6b656e"

  let datum =
    Some(
      ValueRequirements {
        minimum_lovelace: 5_000_000,
        required_token_policy: policy,
        required_token_name: token_name,
        minimum_token_amount: 100,
      },
    )

  let value =
    zero
      |> add(#"", #"", 10_000_000)
      |> add(policy, token_name, 50)

  // Only 50 tokens!
  let script_addr = mock_script_address(0, None)
  let tx =
    mocktail_tx()
      |> tx_in(True, mock_tx_hash(0), 0, value, script_addr)
      |> complete()

  value_validator.spend(datum, Void, mock_utxo_ref(0, 0), tx)
}

test test_value_both_insufficient_fails() fail {
  let policy = mock_policy_id(0)
  let token_name = #"4d79546f6b656e"

  let datum =
    Some(
      ValueRequirements {
        minimum_lovelace: 5_000_000,
        required_token_policy: policy,
        required_token_name: token_name,
        minimum_token_amount: 100,
      },
    )

  let value =
    zero
      |> add(#"", #"", 1_000_000)
      // Insufficient ADA
      |> add(policy, token_name, 25)

  // Insufficient tokens
  let script_addr = mock_script_address(0, None)
  let tx =
    mocktail_tx()
      |> tx_in(True, mock_tx_hash(0), 0, value, script_addr)
      |> complete()

  value_validator.spend(datum, Void, mock_utxo_ref(0, 0), tx)
}
// =============================================================================
// Summary:
// 
// These examples demonstrate:
// 1. Address filtering using find_input and inputs_at from cocktail
// 2. Double-satisfaction prevention with manual single input checking
// 3. Value validation for both lovelace and custom tokens
// 4. Comprehensive test coverage including exploit scenarios
// 
// Key Security Patterns:
// - ALWAYS ensure single script input to prevent double-satisfaction
// - Validate input values, not just output values
// - Combine multiple validation layers for defense in depth
// 
// Note: cocktail module provides inputs_at and outputs_at utilities
// 
// Test Results:
// - All address filtering tests pass
// - Double-satisfaction prevention works correctly
// - Value validation catches insufficient funds
// =============================================================================
