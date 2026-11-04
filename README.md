# SeatLock

A working campus event booking application with persistent Cloudflare D1 storage, ChatGPT authentication, organizer ownership checks and a responsive React interface. Built for Pranav's software engineering portfolio.

## Features
- Discover and search events, category filters and availability sorting.
- One seat per authenticated user per event; atomic five-minute reservations.
- Confirmation, cancellation, rebooking and expiring holds.
- FIFO waitlists with five-minute offers after promotion.
- Personal tickets, calendar downloads and reservation history.
- Organizer event creation/editing/cancellation, attendee CSV export and manual check-in.
- Isolated reliability lab: 80 synthetic reservation attempts for 10 seats using the actual booking SQL.
- Editable sample events, labelled Sample. No fabricated attendance counts.
- Mobile layout, loading/error/empty states, live refresh every eight seconds.

## Architecture
Browser -> Vinext API route -> Cloudflare D1 (SQLite).
Sites authenticates visitors; the server obtains identity through its trusted identity headers. No user ID is accepted from client request bodies. Events have an owner; attendee data, check-in and editing require that owner. User bookings are scoped to authenticated identity.

`lib/queries.json` contains the actual SQL used by both the API and integration tests. Capacity is checked within INSERT...SELECT, a serialized database write. A unique event/user index prevents duplicate seats. Repeated reserve requests do not extend an existing hold. Confirmation retries are idempotent. Expired holds do not consume capacity.

Waitlist promotion runs in an atomic UPDATE selecting the earliest waiting records up to remaining capacity. Ties use the booking UUID for deterministic ordering. Expiration and promotion use transactional D1 batches. A new direct hold is prohibited while anyone is waiting. Capacity reduction uses one conditional UPDATE and cannot go below active reservations. Cancellation closes the event and releases its bookings in one transaction.

## Source map
- `app/page.tsx`: complete interactive client
- `app/globals.css`: responsive design
- `app/api/seatlock/route.ts`: authenticated API and authorization
- `app/chatgpt-auth.ts`: platform identity helper
- `db/schema.ts` and `drizzle/`: database schema and migrations
- `lib/queries.json`: core booking SQL
- `tests/reservations.py`: SQLite concurrency and lifecycle tests
- `tests/api.py`: preview API integration checks

## Development
Dependencies require Node 22.13+. Install using the included setup or `npm run install:ci`. Run `npm run db:generate` after schema changes; inspect migrations before applying. `npm run build` creates the Worker output. Apply the generated SQL locally:

```sh
node --import ./scripts/sites-env.mjs ./node_modules/wrangler/bin/wrangler.js d1 execute DB --local --config dist/server/wrangler.json --persist-to .wrangler/state --file drizzle/0000_salty_swarm.sql
npm run dev
```

The platform provisions the D1 binding declared in `.openai/hosting.json` and applies hosted migrations during deployment. Hosted authentication is supplied by Sites. Development builds supply a synthetic preview organizer when identity is absent; this fallback is compiled out of production builds. For local API tests only, `tests/api.py` uses synthetic identity headers against loopback; these must never be trusted on an independently deployed, internet-exposed origin.

```sh
node node_modules/typescript/bin/tsc --noEmit
python3 tests/reservations.py
python3 tests/api.py http://127.0.0.1:3000
npm run build
```

Use the actual preview origin/port when running API tests.

## Honest operating boundaries
- Free registration; no payment collection, refunds or email/SMS delivery.
- Waitlist offers are visible in the application. Reconciliation occurs on requests/polling, not a background timer. Leave the app open to see promotions. With no traffic, promotion waits until the next request; expiry timestamps still prevent overselling.
- The hosted deployment allows public visitors. Booking still requires ChatGPT authentication. The current hosting URL contains chatgpt.site; removing that hostname requires a custom domain.
- Signed-in visitors can create events and own their own events. This is event ownership, not a global campus-admin permission model.
- Calendar exports assume a two-hour event duration because the current event form captures start time only.
- The lab tests capacity correctness on bounded synthetic load, not high-volume throughput or a production SLA. SQLite tests are not a substitute for testing the hosted runtime.
- Current reservation records retain their latest state; there is no append-only audit log. Ticket IDs are references and do not replace organizer authorization.
- Further production hardening would include per-user rate limits, operational alerting, database backup/restore drills and accessibility review at real scale.

## Interview walkthrough
Reserve the last seat from one user, attempt another booking from a second user, confirm the first, cancel it, then show the second user's waitlist offer. Retry a confirmation and demonstrate a single ticket. Run Reliability lab and show measured outcomes. Discuss why application-side read-then-write counters are unsafe and why atomic SQL is the core guarantee here.

## Verification in this build
TypeScript check and production build passed. All 10 SQLite lifecycle/concurrency tests passed. Browser preview verified discovery, seat hold, confirmation, and the actual D1 lab (80 attempts, 10 accepted, 70 capacity rejections, zero errors, zero oversold seats). The standalone HTTP API test script could not reach the managed preview from the executor network; it is supplied for a locally reachable development server and is not claimed as passed.
