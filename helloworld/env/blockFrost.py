from blockFrost import BlockFrostApi, ApiError, ApiUrls

api = BlockFrostApi(
    project_id="YOUR_BLOCKFROST_API_KEY",  # replace with your key
    base_url=ApiUrls.testnet.value
)

address = "addr_test1vqu2nvxx38fsr66lntqaf5pwkqlp6k97xr3q6nw7tncdmrcw49uea"

try:
    utxos = api.address_utxos(address)
    for utxo in utxos:
        print(
            f"Tx Hash: {utxo.tx_hash}, Index: {utxo.output_index}, Amount: {utxo.amount}")
except ApiError as e:
    print(e)
