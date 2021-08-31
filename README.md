# testnet.bash
Bash script that sets up a private Ethereum network for development and testing.

## Setup

This bash script uses:

1. [`bash`](https://www.gnu.org/software/bash/)
2. [`geth`](https://github.com/ethereum/go-ethereum)
3. [`jq`](https://github.com/stedolan/jq)


## Creating a test network

To bring up a test network, run the [`testnet.bash`](./testnet.bash) script from the root of this
repository as follows:
```bash
mkdir -p testnet
TESTNET_BASE_DIR=testnet/ ./testnet.bash
```

You can run the same command to restart the testnet after shutting it down using `CTRL+C`.

All the account passwords (by default) are `peppercat`.

## Inputs

Accepts inputs through environment variables:

### `TESTNET_BASE_DIR`

Directory in which all data is stored. This is where you will find your node data directories,
dag directories, and more.

If this is not set, will create a temporary directory in which to store all data.

### `GETH`

Set this environment variable to specify a path to a custom `geth`. If not set, will use the first
`geth` available in your `$PATH`.

## Customization

Just copy the bash script and edit it, my friend.

## FAQ

### Why not [Ganache](https://www.trufflesuite.com/ganache)?

Ganache is pretty heavy-duty and I wanted something light-weight that I could use to spin up a private
network, set up a scenario, and then run a series of tests.

Ganache is also a completely independent implementation of the Ethereum interfaces. I wanted to be
able to test against (different versions of) `geth` because that's what we currently use in
[Moonstream](https://github.com/bugout-dev/moonstream). Moonstream crawlers crawl data from `geth`
nodes and any reasonable test of those crawlers should use `geth` nodes.

### Why bash?

Because `bash` is ubiquitous, especially in continuous integration environments.

I have experimented in the past with similar setups in `docker-compose` ([link](https://github.com/the-chaingang/ethereal)).
This bash script does the job just as well, is much simpler to understand, and is much easier to
customize.

### How do I change the genesis parameters?

Copy the bash script and edit the definition of the `GENESIS_JSON` variable.

### How do I add more nodes?

The vanilla script sets up 2 mining nodes. Any less and chain data will not be persisted to disk
between runs. If you wanted to add a third node, you would modify the bash script to add a `run_miner`
call:
```bash
MINER_0=$(run_miner 0)
MINER_1=$(run_miner 1)
MINER_2=$(run_miner 2)
```

If you wanted to print metadata about this new miner, you would add a new `echo` statement near
where the miner metadata is printed:
```bash
echo "Running testnet. Miner info:"
echo "$MINER_0" | jq .
echo "$MINER_1" | jq .
echo "$MINER_2" | jq .
echo
echo "Press CTRL+C to exit."
```

Finally, you would probably want to add the new miner's logs to the tail command:
```bash
tail -f $(echo "$MINER_0" | jq -r ".logfile") $(echo "$MINER_1" | jq -r ".logfile")
```

### Why `geth`?

If you would like to add support for another Ethereum client, I would welcome a pull request.

### Why does this script fail when I try to use a temporary testnet base directory on my Mac?

This script uses `mktemp -d` when you don't specify a testnet directory.

The BSD version of `mktemp` has a different signature than the GNU version. Relevant StackExchange
thread: https://unix.stackexchange.com/questions/30091/fix-or-alternative-for-mktemp-in-os-x

If you want to run this script on a Mac with a temporary base directory, please let me know and I
will add support. At that time, I would appreciate your help in testing the change.

In the meantime, you can get around the issue by explicitly creating a base directory and setting it
as the `TESTNET_BASE_DIR` environment variable.

### Where have you tested `testnet.bash`?

So far, it has been tested on:
- Debian Buster VM image on WSL2 (Windows 10), bash `5.0.3(1)-release`

If you have run this script successfully, I would appreciate it if you submit an edit to this README
describing your environment. Thank you.

### `peppercat`?

<img src="https://s3.amazonaws.com/static.simiotics.com/pepper/pepper-tennis-ball.jpg" width="400"/>

## Contributing

Your contributions are welcome:
- [Create an issue](https://github.com/bugout-dev/testnet.bash/issues/new)
- [Open a pull request](https://github.com/bugout-dev/testnet.bash/compare)
