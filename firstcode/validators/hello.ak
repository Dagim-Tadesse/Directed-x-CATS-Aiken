validator simple {
  spend(_datum, _redeemer, _utxo, _tx) {
    True
  }

  else(_) {
    fail
  }
}
