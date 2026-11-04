# SeatLock — start here

This archive contains the complete frontend, backend, database migrations, tests and build configuration for the deployed SeatLock application.

## What is included

- React + TypeScript frontend: app/page.tsx and app/globals.css
- Backend API: app/api/seatlock/route.ts
- Database schema: db/schema.ts
- Executable SQL migration: drizzle/0000_salty_swarm.sql
- Atomic booking queries: lib/queries.json
- Platform authentication integration: app/chatgpt-auth.ts
- Automated database tests: tests/reservations.py
- API integration test script: tests/api.py
- GitHub checks workflow: .github/workflows/checks.yml
- Architecture and known limits: README.md
- GitHub publishing instructions: GITHUB.md

## Run locally

Install Node.js 24, Python 3 and pnpm 11.25.0. Open a terminal inside this extracted folder.

```sh
npm install --global pnpm@11.25.0
pnpm install --frozen-lockfile
pnpm build
node --import ./scripts/sites-env.mjs ./node_modules/wrangler/bin/wrangler.js d1 execute DB --local --config dist/server/wrangler.json --persist-to .wrangler/state --file drizzle/0000_salty_swarm.sql
pnpm dev
```

Open the local address printed by the development server (normally http://localhost:5173). A development-only preview identity lets you exercise the interface locally. Production builds remove that identity fallback and require platform-authenticated identity.

Apply the SQL migration once to a fresh local database, not every time you start the app. Subsequent starts need only `pnpm dev`.

## Check the code

```sh
pnpm exec tsc --noEmit
python3 tests/reservations.py
pnpm build
```

For a locally reachable dev server, run `python3 tests/api.py http://localhost:5173`. This script uses synthetic local identity headers and must only target a development server.

## Hosting and branding: important distinction

The interface is branded SeatLock. The existing public hosting URL is:
https://seatlock-pranav.lunarkayak.chatgpt.site

The supplied deployment currently depends on Sites authentication and Cloudflare D1. GitHub stores the source; it does not supply those services. GitHub Pages cannot run this backend. A custom domain changes the address, but does not replace the authentication provider.

To host independently with no ChatGPT sign-in, the authentication adapter must be replaced with an identity provider or secure session implementation, then deployed into an account with a persistent database. This archive does not pretend that migration has already been completed.

No AI model is involved in booking; reservations are ordinary backend/database logic.
