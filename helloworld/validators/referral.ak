use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{Transaction}
use cocktail/vodka_validity_range.{valid_after, valid_before}

pub fn is_within(validity_range, timestamp: Int) -> Bool {
  valid_before(validity_range, timestamp) && valid_after(
    validity_range,
    timestamp,
  )
}

pub type Datum {
  owner: VerificationKeyHash,
  referral_hash: ByteArray,
  // issuer_id: ByteArray,
  issued_at: Int,
}

pub type Redeemer =
  Void

validator referral {
  spend(
    datum_opt: Option<Datum>,
    _redeemer: Redeemer,
    _input,
    self: Transaction,
  ) {
    expect Some(Datum { owner, referral_hash, issued_at }) = datum_opt

    let hash_ok = referral_hash != #"00"
    let signed_ok = list.has(self.extra_signatories, owner)
    let time_ok = valid_before(self.validity_range, issued_at)

    hash_ok && signed_ok && time_ok
  }

  else(_) {
    fail
  }
}
