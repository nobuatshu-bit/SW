# Development guide

## Prerequisites

- Node.js 22 LTS and npm 11+
- Go 1.25+
- Foundry
- Docker Desktop (optional for the local service stack)

## Web

```bash
npm install
npm run dev
npm run lint
npm run build
```

## API

```bash
cd backend/api
# Set the variables listed in .env.example in your shell, then:
go mod tidy
go run ./cmd/api
```

The API requires PostgreSQL and Redis. Docker Compose is the simplest way to supply both.

## Contracts

See [contracts/README.md](../contracts/README.md) for dependency installation, build, test, and deployment commands.
