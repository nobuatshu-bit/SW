# Local Docker stack

From this directory, start the complete development stack:

```bash
docker compose up --build
```

Services are available at:

- Web: `http://localhost:3000`
- API health: `http://localhost:8080/health`
- PostgreSQL: `localhost:5432`
- Redis: `localhost:6379`

The Compose database credentials are for local development only. Set `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` in your shell (or a local `.env` in this directory) to enable WalletConnect-based wallets.
