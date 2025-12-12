// validator my_spend {
//   spend(_datum, _redeemer, _input, _tx) {
//     True
//   }

//   else(_) {
//     fail
//   }
// }
// validator my_validator {
//   spend(
//     datum: Option<MyDatum>,
//     // Data locked with UTxO 
//     redeemer: MyRedeemer,
//     // Arguments from spender 
//     input: OutputReference,
//     // Which UTxO being spent 
//     self: Transaction,
//   ) {
//     // Complete transaction context
//     // Your validation logic here    
//     True
//     // or False 
//   }

//   else(_) {
//     fail
//   }
// }

// use aiken/collection/list
// use aiken/crypto.{VerificationKeyHash}
// use cardano/transaction.{OutputReference, Transaction}
// pub type Datum {
//   owner: VerificationKeyHash,
// }
// pub type Redeemer {
//   msg: ByteArray,
// }
// validator hello_world {
//   spend(
//     datum: Option<Datum>,
//     redeemer: Redeemer,
//     _own_ref: OutputReference,
//     self: Transaction,
//   ) {
//     expect Some(Datum { owner }) = datum
//     let must_say_hello = redeemer.msg == "Hello, World!"
//     let must_be_signed = list.has(self.extra_signatories, owner)
//     must_say_hello && must_be_signed
//   }
// }
