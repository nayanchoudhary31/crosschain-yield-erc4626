# Crosschain Yield ERC4626

Upgradeable ERC-4626 yield vault with a backend indexer and REST API. The on-chain vault (UUPS proxy + implementation) enforces custody, accounting, caps, and access control. The off-chain services index events, aggregate stats, and expose APIs backed by Postgres (Prisma).

**Core features**
- Upgradeable UUPS vault with ERC-4626 deposits/withdrawals and a deposit cap. (`src/vault/YieldVault.sol`)
- Yield simulation via privileged `YIELD_ROLE` (adds assets without minting shares). (`src/vault/YieldVault.sol`)
- V1 upgrade adds per-transaction withdraw cap via reinitializer. (`src/vault/YieldVaultV1.sol`)
- Event indexer with confirmation safety and idempotent writes. (`backend/src/indexer/*`)
- REST API for vault stats, user positions, and transactions. (`backend/src/controllers/*`)
- JWT-protected admin endpoints for pause/unpause, cap updates, and simulate yield. (`backend/src/routes/admin.routes.ts`)

**Architecture**
```mermaid
graph LR
  User[User Wallet]
  Admin[Admin Client]

  subgraph OnChain[On-chain]
    P[ERC1967 Proxy]
    I[YieldVault Implementation]
    A[ERC20 Asset - MockUSDC local]
    P --> I
    I --> A
  end

  subgraph OffChain[Off-chain]
    RPC[RPC Node]
    IDX[Indexer - poll and confirmations]
    DB[(Postgres - Prisma)]
    API[REST API /api/v1]
  end

  User -->|deposit and withdraw| P
  I -. emits events .-> RPC
  RPC --> IDX
  IDX --> DB
  DB --> API
  Admin -->|JWT + signer| API
  API -->|pause/unpause/cap/yield| I
```

**On-Chain vs Off-Chain Responsibilities**

On-chain (smart contracts)
- Asset custody and share accounting (ERC-4626)
- Deposit cap enforcement and pause/unpause controls
- Role-based access control (admin + yield role)
- Yield simulation by privileged role
- UUPS upgradeability and storage gap

Off-chain (backend)
- Polls and indexes `Deposit`/`Withdraw` events with confirmations
- Aggregates stats and user positions in Postgres
- Exposes REST API for stats and history
- Admin auth via JWT and on-chain admin calls via signer
- No asset custody (only metadata and analytics)

**Security Considerations**

Three realistic attack vectors in this codebase
1. Admin key compromise
   - Impact: malicious upgrades, pause/unpause abuse, cap manipulation, or fake yield.
   - Mitigation: limit admin key access, use multisig/HSM, rotate keys, and use on-chain timelocks.
2. UUPS upgrade risk
   - Impact: storage layout corruption or malicious logic in new implementation.
   - Mitigation: storage gap, upgrade tests (`test/YieldVault.t.sol`), and strict review of new impls.
3. Indexer/RPC trust risk
   - Impact: reorgs or compromised RPC can cause incorrect off-chain stats.
   - Mitigation: confirmation window (3 blocks), idempotent event writes, and reorg handling strategy.

**Scaling Bottlenecks**

Current bottlenecks to expect
1. Sequential per-block polling and processing in a single loop (`startIndexer`).
2. Per-block database transactions with multiple upserts (write amplification under heavy traffic).

**Monitoring Strategy**

Recommended metrics and alerts
- Indexer lag: `latestBlock - lastSafeBlock`
- Indexer processing time per block and error rate
- API latency (p95/p99) and 5xx rate
- DB connection failures and query latency
- Audit logs for admin actions (pause/unpause/cap/yield)

Suggested tools: Prometheus + Grafana or a hosted APM. This repo does not include monitoring setup.

**Upgrade Explanation**

This project uses UUPS upgradeability:
- `YieldVault` is the base implementation.
- `YieldVaultV1` adds a withdraw cap with `initializeV2` (reinitializer).
- `script/Upgrade.s.sol` performs `upgradeToAndCall` and initializes the new state.
- A storage gap (`__gap`) reserves slots for future upgrades.

**How to Deploy & Run Locally**

Contracts (Anvil + Foundry)
1. Start a local chain:
   ```bash
   anvil
   ```
2. Build and test:
   ```bash
   forge build
   forge test
   ```
3. Deploy proxy + implementation:
   ```bash
   forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --private-key <ANVIL_PRIVATE_KEY> --broadcast
   ```
   Capture the printed `Proxy` and `Implementation` addresses.
4. Upgrade to V1:
   ```bash
   PROXY_ADDRESS=<PROXY_ADDRESS> forge script script/Upgrade.s.sol --rpc-url http://127.0.0.1:8545 --private-key <ANVIL_PRIVATE_KEY> --broadcast
   ```

Backend + Indexer
1. Install deps:
   ```bash
   cd backend
   pnpm install
   ```
2. Set env vars:
   ```bash
   export DATABASE_URL="postgresql://user:pass@localhost:5432/vault"
   export RPC_URL="http://127.0.0.1:8545"
   export VAULT_ADDRESS="<PROXY_ADDRESS>"
   export ADMIN_PRIVATE_KEY="<ADMIN_PRIVATE_KEY>"
   export ADMIN_USERNAME="admin"
   export ADMIN_PASSWORD="password"
   export JWT_SECRET="change_me"
   export PORT=3001
   ```
3. Run migrations:
   ```bash
   pnpm prisma migrate deploy
   ```
4. Start API server:
   ```bash
   pnpm dev
   ```
5. Start indexer in a separate process:
   ```bash
   cd backend
   tsx -e "import { startIndexer } from './src/indexer/indexer.js'; startIndexer();"
   ```

**API Endpoints**
Base path: `/api/v1`
- `GET /vault/stats`
- `GET /user/:address/position`
- `GET /transactions/:address`
- `POST /admin/login`
- `POST /admin/pause`
- `POST /admin/unpause`
- `POST /admin/cap-update`
- `POST /admin/yield-update`

**Test Scenarios**
- `forge test` (includes upgrade test)
- Manual happy path: deposit → simulateYield → withdraw, then verify API stats reflect events
- Indexer resume: stop/start indexer and verify it resumes from `sync_state`
