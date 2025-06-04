# 🐺 Dlord's Aztec-Setup

A complete all-in-one setup script to deploy an **Aztec sequencer validator node**, along with **Sepolia execution (geth)** and **consensus (prysm)** clients — giving you your own fully functional RPC endpoints.

*Can’t afford a paid RPC or a powerful VPS right now?
No worries — I’m happy to share access to my self-hosted Sepolia RPC for just $5. It’s stable, fast, and perfect if you just need something that works.*

Need help or want more features added?  
Follow me on [X (Twitter)](https://x.com/dlordkendex) and tag **@dlordkendex** with your request.

---

## Clone the Setup Repository

Run the following in your terminal to clone this setup script:

```bash
git clone https://github.com/dlordkendex/aztec-setup.git && chmod +x aztec-setup/aztec/aztec.sh aztec-setup/sepolia/sepolia.sh aztec-setup/sepolia/checkup.sh && cd aztec-setup
```

### Directory Structure:
```
aztec-setup/
├── aztec/
│   └── aztec.sh
└── sepolia/
    ├── sepolia.sh
    └── checkup.sh
```

---

# 🔪 Aztec Node Setup

Deploy and run an Aztec sequencer validator node on **Ubuntu 20.04 or higher** using this simple auto-setup script.

### Minimum Requirements:
- 8 CPU cores  
- 16 GB RAM  
- 100+ GB SSD  

### Get Started:

1. **Enter the Aztec directory:**
   ```bash
   cd aztec
   ```

2. **Run the setup menu:**
   ```bash
   ./aztec.sh
   ```

### Menu Options:
- **[1] Install/Reinstall**: Installs the Aztec Docker image  
- **[2] Edit .env file**: Configure your environment variables  
- **[3] Start/Restart**: Starts the Aztec node  
- **[4] Logs**: View node logs (press `Ctrl + C` to exit)  
- **[5] Status**: Check node status  
- **[6] Stop**: Stop the node  
- **[7] Shell**: Enter the node container shell  
- **[10] Info**: Retrieve block number, proof, and peer ID  
- **[RESET]**: Factory reset — use only if necessary  
- **[0] Exit**: Exit the menu  

### Need Help?
Join the [Aztec Discord](https://discord.gg/aztecprotocol) — check the `#operators | starts-here` channel.

---

# ⬛ Sepolia Setup

Deploy and run **Sepolia Execution (geth)** and **Consensus (prysm)** clients on **Ubuntu 20.04 or higher** using this script.

### Minimum Requirements:
- 8 CPU cores  
- 16 GB RAM  
- 1 TB SSD  

### Get Started:

1. **Enter the Sepolia directory:**
   ```bash
   cd sepolia
   ```

2. **Run the setup menu:**
   ```bash
   ./sepolia.sh
   ```

### Menu Options:
- **[1] Install/Reinstall**: Installs Geth and Prysm Docker images  
- **[3] Start/Restart**: Starts both clients  
- **[4] Logs**: View logs (press `Ctrl + C` to exit)  
- **[5] Status**: Check node status  
- **[6] Stop**: Stop the node  
- **[7] Shell**: Enter the container shell  
- **[10] Checkup**: Verifies availability of RPC endpoints  
- **[RESET]**: Factory reset — use only if necessary  
- **[0] Exit**: Exit the menu  

**Note:**  
Sepolia sync can take **up to 4 hours**.

### Post-Sync RPC Endpoints:
- **Execution Client RPC:** `http://your-ip-address:8545`  
- **Consensus Client RPC:** `http://your-ip-address:3500`

---

# What currently works for me
# VPS Specs, Real Usage Example this is relatable.

I currently run the **Aztec sequencer** and **Sepolia Geth/Prysm clients** on a single VPS.

### My VPS Specs:
- 8 CPU cores  
- 30 GB RAM  
- 1.2 TB SSD  

### Active Resource Usage:
- **CPU:** All 8 cores  
- **RAM:** ~8 GB used, ~22 GB free  
- **Storage:** ~700 GB used, ~500 GB free  

This real-world usage should help you decide what VPS setup best suits your needs and budget.

**Results when i ran the checkup**
All doesn't have to pass for your sepolia RPCs to work with aztec sequencer
```
Checking EL RPC methods...

Checking CL REST endpoints...

✅ EL methods passed: 22
❌ EL methods failed: 13
  - web3_clientVersion
  - ["0x68656c6c6f20776f726c64"]
  - net_peerCount
  - eth_protocolVersion
  - eth_coinbase
  - eth_hashrate
  - eth_accounts
  - eth_sign
  - eth_sendTransaction
  - eth_sendRawTransaction
  - eth_newBlockFilter
  - eth_getFilterChanges
  - eth_getFilterLogs

✅ CL endpoints passed: 11
❌ CL endpoints failed: 7
  - /eth/v1/node/health
  - /eth/v1/debug/beacon/states/head
  - /eth/v1/events
  - /eth/v1/validator/duties/proposer/1
  - /eth/v1/validator/duties/attester/1
  - /eth/v1/validator/blocks/1
  - /eth/v1/validator/sync_committees/1

All checks complete.
```
