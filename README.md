# K2 - The Koii Settlement Layer
![K2 - Tick, Tock, Fast Blocks](https://docs.koii.network/assets/images/K2%20-%20Tick,%20Tock,%20Fast%20Blocks-5d576dbf6310f66a79e36af376974f24.svg)
# Running a K2 Node

_At this time we only support Ubuntu 20.04 LTS. We offer macOS and Windows binaries however we do not have official guides on how to set up your validator environment on those operating systems._

## Staking

There is no minimum amount of KOII required to stake and participate in the voting process.

To participate in the voting process you must configure your system, start a validator and configure your voting and stake accounts. This guide will show you how to do this.

## Quick Links

1. [System Requirements](README.md#system-requirements)
2. [System Setup](README.md#system-setup)
3. [Validator Setup](README.md#validator-setup)
4. [K2 Releases](https://github.com/koii-network/k2-release/releases)

## System Requirements
To run a K2 node, you need some KOII tokens and also possess the minimum memory (128 GB or 258 GB), computational (12 or 16 cores), and storage requirements.

There is no strict minimum amount of KOII tokens required to run the K2 node.

### Minimum Hardware Requirements

Here are the minimum hardware requirements for running a K2 node in terms of memory, compute, storage, and your operating system:

**1. Memory**

- 128GB, or more for consensus validator nodes
- 258GB, or more for RPC nodes

**2. Compute**

- 12 cores / 24 threads, or more @ minimum of 2.8GHz for consensus validator nodes
- 16 cores / 32 threads, or more for RPC nodes

**3. Storage**

For consensus validators:

- PCIe Gen3 x4 NVME SSD, or better
- Accounts: 500GB, or larger. High TBW (Total Bytes Written)
- Ledger: 1TB or larger. High TBW suggested

For RPC nodes:

- A larger ledger disk if longer transaction history is required, Accounts and ledger should not be stored on the same disk
- GPUs are not strictly necessary
- Network: 1 GBPS up and downlink speed, must be unshaped and unmetered

**4. Operating System**

Currently we are only supporting Ubuntu 20.04 for our validators. We do provide binaries for other operating systems however the operation of these binaries is not guaranteed.

## System Setup

<Description
  text="This section provides a guide for how to configure your Ubuntu system"
/>

Before continuing with this section you should ensure that your environment is up to date:

```bash
sudo apt update
sudo apt upgrade
```

After updating your environment you will need to install the required packages

```bash
sudo apt install libssl-dev libudev-dev pkg-config zlib1g-dev llvm clang
```

### Step 1: Create a new user

We recommend running the validator under a user that is not `root` for security reasons. Create a user to run the validator

```bash
sudo adduser koii
sudo usermod -aG sudo koii
```

Elevate into the user

```bash 
sudo su koii
```

### Step 2: Install the Koii software

We host an install script that will install and configure the Koii validator software. Run it with the following command

```bash
sh -c "$(curl -sSfL https://raw.githubusercontent.com/koii-network/k2-release/master/k2-install-init.sh/koii-install-init.sh)"
```

This scipt will install and configure the validator software with an identity key and the `koii` cli configured for `testnet`. It is important to note that this identity key created IS NOT your validator identity. If you have a private key which is funded for staking with a validator you can replace the one generated with this script. 

If everything is configured correctly you can test it by running `koii balance` which will return the balance of the local key.

## Validator Setup

The following guide describes how to setup a validator on Ubuntu.

### Identity Setup
You will need to create the following keys on your system:

```bash
koii-keygen new --outfile ~/validator-keypair.json
koii-keygen new --outfile ~/withdrawer-keypair.json
koii-keygen new --outfile ~/stake-account-keypair.json
koii-keygen new --outfile ~/vote-account-keypair.json

```
The authorized-withdrawer keypair is to be used as the ultimate authority over your validator. This keypair will be able to withdraw from your vote account and will have additional permission to change all other aspects of your vote account.

This is a very important keypair since anyone in possession of it has the ability to permanently take control of your vote account and make any changes they please. Therefore, it's crucial to store your authorized-withdrawer keypair in a secure location.

It doesn't have to be stored on your validator, and it shouldn't be stored anywhere where unauthorized people could access it.

It's recommended that you use `systemctl` to manage the validator process. To set up the validator service you can complete the following steps.

### Step 1: Create a Systemctl Service File for the Validator

Write a service configuration using the editor of your choice (nano, vim, etc). Do this as a system user with root permissions, not your validator user.

```bash
sudo nano /etc/systemd/system/koii-validator.service
```

Paste the service configuration below into your editor.

```makefile
[Unit]
Description=Koii Validator
After=network.target

[Service]
User=koii
Group=koii
Environment="PATH=/home/koii/.local/share/koii/install/active_release/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
ExecStart=/home/koii/.local/share/koii/install/active_release/bin/koii-validator --identity /home/koii/validator-keypair.json --ledger /home/koii/validator-ledger --accounts /home/koii/validator-accounts --entrypoint k2-testnet-validator-1.koii.live:10001 --rpc-port 10899 --dynamic-port-range 10000-10500 --limit-ledger-size --gossip-port 10001 --log - --rpc-bind-address 0.0.0.0
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Save and close your editor.

### Step 2: Enable and Start the Koii Validator Service

Enable the service

```bash
sudo systemctl enable koii-validator.service
```

Start the service

```bash
sudo systemctl start koii-validator.service
```

Check the service status

```bash
sudo systemctl status koii-validator.service
```

### Step 3: Create a Vote Account

_**You will need your validator keypair to be funded with KOII tokens and have the validator service running before continuing.**_

For the remainder of the steps please elevate your user to your validator account.

```bash
sudo su koii
```

Using the keys created in the first portion of this guide, create a vote account.

```bash
koii create-vote-account ~/vote-account-keypair.json ~/validator-keypair.json ~/withdrawer-keypair.json
```

### Step 4: Create a Stake Account

Create the staking account using the validator's identity keypair and the authorized withdrawer keypair:

```bash
koii create-stake-account ~/stake-account-keypair.json <AMOUNT_TO_STAKE> --stake-authority ~/validator-keypair.json --withdraw-authority ~/withdrawer-keypair.json
```

Where `<AMOUNT_TO_STAKE>` is the number of tokens you want to stake with.

### Step 5: Play Catchup

Make sure your validator is caught up with the network.

```bash
koii catchup ~/validator-keypair.json
```

### Step 6: Delegate Your Stake

Delegate the stake to the validator using the staking account and validator's identity keypair:

```bash
koii delegate-stake ~/stake-account-keypair.json <VALIDATOR_VOTE_ACCOUNT_ADDRESS> --stake-authority ~/validator-keypair.json
```

Replace `<VALIDATOR_VOTE_ACCOUNT_ADDRESS>` with the validator's public address which can be found using the `koii validator-info get` command.
