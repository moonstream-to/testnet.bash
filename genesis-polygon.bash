#!/usr/bin/env bash

# Representation of pseudo-Polygon blockchain genesis.json.

set -e -o pipefail

GENESIS_JSON="$1"
GENESIS_JSON_CHAIN_ID="$2"

cat <<EOF >"$GENESIS_JSON"
{
  "config": {
    "chainId": $GENESIS_JSON_CHAIN_ID,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0
  },
  "alloc": {},
  "coinbase": "0x0000000000000000000000000000000000000000",
  "difficulty": "0x20000",
  "extraData": "",
  "gasLimit": "0x1312d00",
  "nonce": "0x0037861100000042",
  "mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "timestamp": "0x00"
}
EOF
