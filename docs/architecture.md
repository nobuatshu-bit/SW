# Architecture

SHERWOOD is organized as an independently deployable web app, API, and contract workspace, with reusable TypeScript packages shared across product surfaces.

```text
apps/web ── browser/API ──> backend/api ──> PostgreSQL
     │                          │
     └── viem / wagmi ──────────┴──> Base Sepolia
                                │
                                └──> Redis
```

## Frontend

`apps/web` uses the Next.js App Router with strict TypeScript. A client-only provider composition owns wagmi, RainbowKit and TanStack Query. Zustand is reserved for local UI state; server data should use TanStack Query. Forms should pair React Hook Form with Zod schemas.

The shadcn-compatible component configuration lives in `apps/web/components.json`; reusable primitives are published from `@sherwood/ui`.

## API

The Go API follows dependency direction from delivery to application to domain. Infrastructure adapters for PostgreSQL and Redis sit outside the core. New features should define domain interfaces first, then inject infrastructure at the composition root in `cmd/api`.

Configuration is entirely environment-driven. The `/health` endpoint provides basic liveness plus PostgreSQL and Redis check results.

## Smart contracts

Foundry configuration targets Base Sepolia and externalizes RPC and explorer credentials. `Counter` exists solely to ensure the deployment and test workflow works. Product/launchpad contracts are intentionally absent.
