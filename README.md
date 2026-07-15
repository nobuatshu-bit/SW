# SHERWOOD

Production-ready Web3 platform foundation. Launchpad business logic is intentionally out of scope.

## Repository layout

- `apps/web` — Next.js application
- `backend/api` — Gin HTTP API
- `contracts` — Foundry Solidity workspace
- `packages/sdk` — typed API and contract-client primitives
- `packages/shared` — shared TypeScript utilities and schemas
- `packages/ui` — reusable UI components
- `infra/docker` — local container orchestration
- `docs` — architecture and operating documentation

## Quick start

```bash
npm install
npm run dev
```

Copy environment templates before running services:

```bash
Copy-Item apps/web/.env.example apps/web/.env.local
Copy-Item backend/api/.env.example backend/api/.env
```

For the full local stack, see [infra/docker/README.md](infra/docker/README.md).
