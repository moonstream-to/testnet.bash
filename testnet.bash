#!/usr/bin/env bash

# Source: https://github.com/bugout-dev/testnet.bash

# This script sets up an Ethereum test network using 2 miners.
# Assumptions:
# - geth available on PATH
# - jq available on PATH
# - The password is always "peppercat" (without the quotes)

# Accepts the following environment variables as inputs:
# - TESTNET_BASE_DIR: Directory into which all testnet data goes for all nodes.

set -e -o pipefail

function usage() {
    echo "$0 [-h]"
    echo
    echo "Starts an Ethereum testnet consisting of two mining nodes and a preconfigured genesis block."
    echo "Any changes to network topology or configuration should be made by editing this file."
    echo "Respects the following environment variables:"
    echo "TESTNET_BASE_DIR"
    echo -e "\tUse this environment variable to specify a directory in which to persist blockchain state. If this variable is not specified, a temporary directory will be used."
    echo "PASSWORD_FOR_ALL_ACCOUNTS"
    echo -e "\tUse this environment variable to specify a password that unlocks all miner accounts in the testnet. Default: 'peppercat' (without the quotes)."
    echo "GENESIS_JSON_CHAIN_ID"
    echo -e "\tUse this environment variable to specify a chain ID to write into the genesis.json for your testnet. Default: 1337."
    echo
    echo "Optional arguments:"
    echo "  -a  Address for http web3 server. Default: 127.0.0.1."
    echo "  -b  Blockchain config to run [ethereum/polygon]. Polygon blockchain is pseudo-polygon blockchain, running by geth with modified genesis file. Default: ethereum."
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]
then
    usage
    exit 2
fi

FLAG_HTTP_ADDR="127.0.0.1"
FLAG_BLOCKCHAIN="ethereum"
while getopts 'ab:' flag; do
    case "${flag}" in
        a) FLAG_HTTP_ADDR="${OPTARG}" ;;
        b) FLAG_BLOCKCHAIN="${OPTARG}" ;;
        *) usage
        exit 2 ;;
    esac
done

PASSWORD_FOR_ALL_ACCOUNTS="${PASSWORD_FOR_ALL_ACCOUNTS:-peppercat}"

GETH="${GETH:-geth}"

TESTNET_BASE_DIR="$TESTNET_BASE_DIR"
if [ -z "$TESTNET_BASE_DIR" ]
then
    TESTNET_BASE_DIR="$(mktemp -d)"
    echo "TESTNET_BASE_DIR not provided. Using temporary directory: $TESTNET_BASE_DIR" 1>&2
fi

if [ ! -d "$TESTNET_BASE_DIR" ]
then
    echo "Base directory does not exist or is not a directory: $TESTNET_BASE_DIR"
    exit 1
fi

PIDS_FILE="$TESTNET_BASE_DIR/pids.txt"
BOOTNODES_FILE="$TESTNET_BASE_DIR/bootnodes.txt"
# Reset PID and bootnode metadata
rm -f "$BOOTNODES_FILE" "$PIDS_FILE"
touch "$PIDS_FILE" "$BOOTNODES_FILE"

MINERS_FILE="$TESTNET_BASE_DIR/miners.txt"
if [ -f "$MINERS_FILE" ]
then
    rm "$MINERS_FILE"
fi

# Generate genesis file
# Modify this if you would like to change the genesis parameters.
GENESIS_JSON="$TESTNET_BASE_DIR/genesis.json"
GENESIS_JSON_CHAIN_ID="${GENESIS_JSON_CHAIN_ID:-1337}"
if [ "$FLAG_BLOCKCHAIN" == "ethereum" ]; then
    MINER_GASPRICE=1000000000
    MINER_GASLIMIT=8000000
    bash genesis-ethereum.bash "$GENESIS_JSON" "$GENESIS_JSON_CHAIN_ID"
elif [ "$FLAG_BLOCKCHAIN" == "polygon" ]; then
    MINER_GASPRICE=30000000000
    MINER_GASLIMIT=20000000
    bash genesis-polygon.bash "$GENESIS_JSON" "$GENESIS_JSON_CHAIN_ID"
else
    echo "Unsupported blockchain: $FLAG_BLOCKCHAIN"
    exit 1
fi

function run_miner() {
    MINER_INDEX=$1
    PASSWORD_FILE="$TESTNET_BASE_DIR/password.txt"
    if [ ! -f "$PASSWORD_FILE" ]
    then
        echo "$PASSWORD_FOR_ALL_ACCOUNTS" >"$PASSWORD_FILE"
    fi
    MINER_LABEL="miner-$MINER_INDEX"
    MINER_HTTP_PORT="$2"
    MINER_LISTENING_PORT="$3"
    MINER_LOGFILE="$TESTNET_BASE_DIR/$MINER_LABEL.log"
    MINER_DATADIR="$TESTNET_BASE_DIR/$MINER_LABEL"
    echo "Creating data directory for miner: $MINER_LABEL -- $MINER_DATADIR" 1>&2
    mkdir "$MINER_DATADIR"

    ETHASH_DIR="$TESTNET_BASE_DIR/ethash"
    if [ ! -d "$ETHASH_DIR" ]
    then
        mkdir "$ETHASH_DIR"
    fi
    MINER_DAGDIR="$ETHASH_DIR/$MINER_LABEL"

    KEYSTORE_DIR="$MINER_DATADIR/keystore"
    mkdir -p "$KEYSTORE_DIR"
    OLDEST_ACCOUNT_FILE=$(ls -1tr "$KEYSTORE_DIR")
    if [ -z "$OLDEST_ACCOUNT_FILE" ]
    then
        "$GETH" account new --datadir "$MINER_DATADIR" --password "$PASSWORD_FILE" >>"$MINER_LOGFILE"
        OLDEST_ACCOUNT_FILE=$(ls -1tr "$MINER_DATADIR/keystore/")
    fi

    MINER_ADDRESS=$(jq -r ".address" "$KEYSTORE_DIR/$OLDEST_ACCOUNT_FILE")

    "$GETH" init --datadir "$MINER_DATADIR" "$GENESIS_JSON"

    BOOTNODE="$(head -n1 $BOOTNODES_FILE)"

    if [ -z "$BOOTNODE" ]
    then
        set -x
        "$GETH" \
            --datadir="$MINER_DATADIR" \
            --ethash.dagdir="$MINER_DAGDIR" \
            --mine \
            --miner.threads=1 \
            --miner.gasprice="$MINER_GASPRICE" \
            --miner.gaslimit="$MINER_GASLIMIT" \
            --miner.etherbase="$MINER_ADDRESS" \
            --port="$MINER_LISTENING_PORT" \
            --http \
            --http.addr "$FLAG_HTTP_ADDR" \
            --http.port "$MINER_HTTP_PORT" \
            --http.api eth,web3,txpool,miner,personal,debug \
            --allow-insecure-unlock \
            --networkid=1337 \
            >>"$MINER_LOGFILE" 2>&1 \
            &
        set +x
    else
        set -x
        "$GETH" \
            --datadir="$MINER_DATADIR" \
            --ethash.dagdir="$MINER_DAGDIR" \
            --mine \
            --miner.threads=1 \
            --miner.gasprice="$MINER_GASPRICE" \
            --miner.gaslimit="$MINER_GASLIMIT" \
            --miner.etherbase="$MINER_ADDRESS" \
            --port="$MINER_LISTENING_PORT" \
            --http \
            --http.addr "$FLAG_HTTP_ADDR" \
            --http.port "$MINER_HTTP_PORT" \
            --http.api eth,web3,txpool,miner,personal,debug \
            --allow-insecure-unlock \
            --networkid=1337 \
            --bootnodes "$BOOTNODE" \
            >>"$MINER_LOGFILE" 2>&1 \
            &
        set +x
    fi

    PID="$!"
    echo "$PID" >>"$PIDS_FILE"

    if [ -z "$BOOTNODE" ]
    then
        until "$GETH" attach --exec "console.log(admin.nodeInfo.enode)" "$MINER_DATADIR/geth.ipc" | head -n1 >"$BOOTNODES_FILE"
        do
            sleep 1
        done
    fi

    echo "{\"miner\": \"$MINER_LABEL\", \"address\": \"$MINER_ADDRESS\", \"pid\": $PID, \"datadir\": \"$MINER_DATADIR\", \"logfile\": \"$MINER_LOGFILE\"}"
}

function cancel() {
    while read -r pid
    do
        echo "Killing process: $pid" 1>&2
        kill -2 "$pid"
    done <"$PIDS_FILE"

    while read -r pid
    do
        while kill -0 "$pid"
        do
            echo "Waiting for process to die..." 1>&2
            sleep 1
        done
        echo "Process killed: $pid" 1>&2
    done <"$PIDS_FILE"
}

trap cancel SIGINT SIGTERM SIGKILL

# Add additional nodes here.
MINER_0=$(run_miner 0 8545 30303)
MINER_1=$(run_miner 1 8546 30304)

echo "Running testnet. Miner info:"
echo "$MINER_0" | tee -a $MINERS_FILE | jq .
echo "$MINER_1" | tee -a $MINERS_FILE | jq .
echo
echo "Press CTRL+C to exit."

tail -f $(echo "$MINER_0" | jq -r ".logfile") $(echo "$MINER_1" | jq -r ".logfile")
