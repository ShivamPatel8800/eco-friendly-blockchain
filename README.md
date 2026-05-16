<div align="center">

<img src="https://img.shields.io/badge/Solidity-0.8.28-363636?style=for-the-badge&logo=solidity&logoColor=white"/>
<img src="https://img.shields.io/badge/Hardhat-2.22-fff100?style=for-the-badge&logo=hardhat&logoColor=black"/>
<img src="https://img.shields.io/badge/OpenZeppelin-5.0-4E5EE4?style=for-the-badge&logo=openzeppelin&logoColor=white"/>
<img src="https://img.shields.io/badge/TypeScript-5.0-3178C6?style=for-the-badge&logo=typescript&logoColor=white"/>
<img src="https://img.shields.io/badge/Ethers.js-6.0-2535a0?style=for-the-badge"/>

<br/><br/>

# 🌿 Eco-Friendly Consensus Mechanism

### A decentralised system for logging, verifying, and rewarding real-world eco-friendly activities on-chain.

<br/>

[Overview](#-overview) •
[Architecture](#-architecture) •
[Contracts](#-smart-contracts) •
[Rewards](#-reward-tiers) •
[Quickstart](#-quickstart) •
[Scripts](#-scripts) •
[Roles](#-access-control) •
[Roadmap](#-roadmap)

<br/>

</div>

---

## 🌍 Overview

The **Eco-Friendly Consensus Mechanism** is a smart contract system deployed on EVM-compatible blockchains. It incentivises real-world environmental action — tree planting, recycling, solar energy adoption, and more — by rewarding verified participants with **EcoFriendly Tokens (EFT)**.

Activities go through a **multi-validator consensus** process before rewards are minted, ensuring that only legitimate, proof-backed submissions are rewarded. Validators who hold staked EFT gain governance weight, aligning incentives between the system and its participants.

```
User submits activity + IPFS proof hash
        ↓
Validators cast votes (approve / reject)
        ↓
Quorum reached → Activity finalised automatically
        ↓
Approved → EFT minted directly to user's wallet
```

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    EcoToken (EFT)                           │
│  ERC-20 · AccessControl · Pausable                          │
│                                                             │
│  ┌─────────────────┐  ┌──────────────────┐                  │
│  │   mint()        │  │  stake()         │                  │
│  │  DISTRIBUTOR    │  │  unstake()       │                  │
│  │  ROLE only      │  │  7-day lock      │                  │
│  └─────────────────┘  └──────────────────┘                  │
│                        governanceWeight(user)               │
└────────────────────────────┬────────────────────────────────┘
                             │ DISTRIBUTOR_ROLE granted
                             │ mint() called on approval
┌────────────────────────────▼────────────────────────────────┐
│                    EcoTracker                               │
│  AccessControl · Pausable · ReentrancyGuard                 │
│                                                             │
│  logActivity(category, description, proofHash)              │
│  castVote(activityId, approve)   quorum = 2                 │
│  expireActivity(activityId)      3-day window               │
│  setQuorum(n)                    admin only                 │
└─────────────────────────────────────────────────────────────┘
```

### Activity Lifecycle

```
                    ┌──────────┐
                    │  User    │
                    └────┬─────┘
                         │ logActivity()
                         ▼
                    ┌──────────┐
                    │ Pending  │◄─── validators cast votes
                    └────┬─────┘
           ┌─────────────┼──────────────┐
     quorum ✓       quorum ✗        3 days pass
           │             │               │
           ▼             ▼               ▼
      ┌──────────┐ ┌──────────┐  ┌──────────┐
      │ Approved │ │ Rejected │  │ Expired  │
      │ EFT mint │ │no reward │  │no reward │
      └──────────┘ └──────────┘  └──────────┘
```

---

## 📄 Smart Contracts

### `EcoToken.sol`

| Feature | Detail |
|---|---|
| Standard | ERC-20 |
| Symbol | `EFT` |
| Decimals | 18 |
| Minting | Restricted to `DISTRIBUTOR_ROLE` (EcoTracker) |
| Staking | `stake()` locks tokens for 7 days; earns governance weight |
| Unstaking | `unstake()` available after lock period |
| Governance | `governanceWeight(user)` returns staked balance |
| Emergency | `pause()` / `unpause()` via `PAUSER_ROLE` |

### `EcoTracker.sol`

| Feature | Detail |
|---|---|
| Consensus | Multi-validator voting, configurable quorum (default: 2) |
| Voting window | 3 days (`VOTE_WINDOW`) |
| Proof storage | IPFS CID or any content hash stored on-chain |
| Categories | 7 activity categories via enum |
| Expiry | Anyone can call `expireActivity()` after deadline |
| History | `getUserActivityIds(user)` per-user on-chain index |
| Security | `ReentrancyGuard` on vote/mint path |
| Emergency | `pause()` / `unpause()` via `PAUSER_ROLE` |

---

## 🏆 Reward Tiers

| Activity | Category ID | Reward |
|---|:---:|---:|
| 🌳 Tree Planting | 0 | **100 EFT** |
| ☀️ Solar Energy | 2 | **50 EFT** |
| 🦋 Biodiversity Protection | 5 | **40 EFT** |
| 💨 Carbon Offset | 4 | **30 EFT** |
| 💧 Water Conservation | 3 | **20 EFT** |
| ♻️ Recycling | 1 | **10 EFT** |
| 🌱 Other | 6 | **1 EFT** |

> Rewards use 18 decimal precision (e.g. `100 EFT = 100 * 10^18` on-chain).

---

## ⚡ Quickstart

### Prerequisites

- [Node.js](https://nodejs.org/) v18+
- npm v9+
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/ShivamPatel8800/eco-friendly-blockchain.git
cd eco-friendly-blockchain

# Install dependencies
npm install

# Compile contracts
npm run compile

# Deploy to local Hardhat network
npm run deploy

# Run end-to-end smoke test
npm run verify
```

### Expected deploy output

```
╔══════════════════════════════════════════════════╗
║  Eco-Friendly Consensus Mechanism — Deployment   ║
╚══════════════════════════════════════════════════╝

Deployer  : 0xf39F...2266
Validator1: 0x7099...79C8
Validator2: 0x3C44...93BC

► Deploying EcoToken...
  ✓ EcoToken  → 0x5FbDB...0aa3
► Deploying EcoTracker (quorum = 2)...
  ✓ EcoTracker → 0xe7f1...0512
► Granting DISTRIBUTOR_ROLE to EcoTracker...
  ✓ Role granted

╔══════════════════════════════════════════════════╗
║                Deployment complete               ║
╚══════════════════════════════════════════════════╝
  Saved → deployment.json
```

---

## 📁 Project Structure

```
eco-friendly-blockchain/
├── contracts/
│   ├── EcoToken.sol       # ERC-20 token with staking + governance
│   └── EcoTracker.sol     # Activity logging + multi-validator consensus
├── scripts/
│   ├── deploy.ts          # Full deployment with role setup
│   └── verify.ts          # End-to-end smoke test
├── test/                  # Unit tests (add your own here)
├── hardhat.config.ts      # Hardhat configuration
├── package.json
├── tsconfig.json
└── deployment.json        # Auto-generated after deploy
```

---

## 🛠 Scripts

| Command | Description |
|---|---|
| `npm run compile` | Compile all Solidity contracts |
| `npm run deploy` | Deploy to local Hardhat network |
| `npm run verify` | Run end-to-end smoke test |
| `npm test` | Run unit tests in `test/` |
| `npm run test:gas` | Run tests with gas usage report |
| `npm run clean` | Wipe artifacts, cache, and deployment.json |

---

## 🔐 Access Control

| Role | Held by | Permissions |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` | Deployer | Grant/revoke all roles, `setQuorum()` |
| `DISTRIBUTOR_ROLE` | EcoTracker contract | `mint()` EFT tokens |
| `VALIDATOR_ROLE` | Admin + extra validators | `castVote()` on activities |
| `PAUSER_ROLE` | Admin | `pause()` / `unpause()` both contracts |

---

## 🌐 Deploying to a Testnet (Sepolia)

1. Create a `.env` file in the project root:

```env
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
DEPLOYER_PRIVATE_KEY=0xYOUR_PRIVATE_KEY
```

2. Install `dotenv`:

```bash
npm install dotenv
```

3. Uncomment the `sepolia` block in `hardhat.config.ts`:

```typescript
sepolia: {
  url:      process.env.SEPOLIA_RPC_URL ?? "",
  accounts: process.env.DEPLOYER_PRIVATE_KEY
              ? [process.env.DEPLOYER_PRIVATE_KEY]
              : [],
},
```

4. Deploy:

```bash
npx hardhat run scripts/deploy.ts --network sepolia
```

> ⚠️ Never commit your `.env` file. Add it to `.gitignore`.

---

## 🔒 Security Considerations

- **ReentrancyGuard** protects the `castVote()` → `mint()` path from re-entrancy attacks
- **Multi-validator consensus** prevents a single compromised validator from approving fraudulent activities
- **Vote deadline** prevents perpetually pending activities from being exploited later
- **Role separation** means the minting key (`DISTRIBUTOR_ROLE`) is held only by the on-chain tracker contract, never by an EOA
- **Pausable** allows emergency shutdown of both contracts independently

---

## 🗺 Roadmap

- [ ] Unit test suite (`test/EcoToken.ts`, `test/EcoTracker.ts`)
- [ ] Stake-weighted validator voting (quadratic or time-weighted)
- [ ] IPFS integration for proof hash verification
- [ ] Sepolia / Polygon Mumbai testnet deployment
- [ ] Frontend dApp (React + wagmi + viem)
- [ ] Multi-sig admin via Gnosis Safe
- [ ] On-chain governance via staked EFT (DAO voting)
- [ ] NFT badges for milestone eco-contributors

---

## 📜 License

MIT — see [LICENSE](LICENSE) for details.

---

<div align="center">

Built with 🌱 for a greener planet · Powered by [Hardhat](https://hardhat.org) · Secured by [OpenZeppelin](https://openzeppelin.com)

</div>
