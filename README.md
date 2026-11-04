# SeatLock

Campus event reservations with timed seat holds and a fair waitlist.

[Live demo](https://seatlock-roan.vercel.app) · [Verification](VERIFICATION.md)

## The problem

When several people reserve the last seat at once, a booking system must prevent overselling without leaving abandoned reservations locked forever. SeatLock uses transactional reservations, five-minute holds and FIFO waitlist promotion to handle that lifecycle.

## Features

- Search, filter and sort campus events.
- Hold one seat per account, confirm a reservation or release it.
- Join a waitlist and receive a timed hold when capacity becomes available.
- Create, edit and cancel events as an organizer.
- View attendee lists, export CSV files and check in confirmed tickets.
- Export events to a calendar and manage active and past tickets.
- Run an isolated 80-request reliability demonstration against a capacity of 10.

## Architecture

| Layer | Implementation |
| --- | --- |
| Interface | Next.js App Router, React, TypeScript and Tailwind CSS |
| API | Next.js route handlers forwarding authenticated RPC requests |
| Identity | Supabase email/password authentication |
| Reservations | PostgreSQL transaction functions with server-side identity checks |
| Hosting | Vercel, connected to this repository |

The database derives the caller's identity from the verified JWT. Organizer actions check event ownership. Direct client access to the event and booking tables is revoked; authenticated RPC functions expose the permitted operations.

A global transaction lock serializes booking mutations. The booking clock is refreshed after acquiring that lock, so expiry decisions do not use a timestamp captured before a long wait. This favors correctness for small event workloads; higher traffic would benefit from narrower locking and separate read/maintenance transactions.

## Local development

Use Node.js 22 or newer:

```sh
npm ci
npm run dev
```

Open http://localhost:3000. To check a production build:

```sh
npm run build
npm run typecheck
```

The Supabase URL and publishable key in `lib/supabase.ts` and `app/api/seatlock/route.ts` are public client configuration. To use a separate database, replace both configurations. Never commit service-role keys, passwords or access tokens.

## Database setup

Apply `supabase/001_seatlock.sql` once to a fresh Supabase project. The configured live database is already initialized; do not reapply the baseline there. Incremental upgrades are stored in `supabase/migrations/`.

`supabase/test-booking.sql` checks duplicate prevention, capacity, waitlists, promotion, expiry, ownership, closure and deleted-account rejection inside a transaction that is rolled back. Run it against a test database with the baseline schema installed.

## Validation

GitHub Actions runs the production build and TypeScript checks on pushes and pull requests. The verification record also covers API booking workflows and the isolated reliability lab: 80 requests, 10 accepted, 70 capacity rejections, zero errors and no oversold seats. That result demonstrates the bounded scenario; it is not a general throughput benchmark.

See [VERIFICATION.md](VERIFICATION.md) for test scope and limitations.

## Deployment

The Vercel project is connected to `CodeWith-Pranav/SeatLock`. Pushes to `main` trigger production deployments and pull requests receive preview deployments. A new deployment uses the Next.js preset, `npm ci` for installation and `npm run build` for the build.

## Scope and tradeoffs

Email confirmation is disabled for the public demo, so signup does not verify email ownership. Verified-email signup requires SMTP configuration, allowed redirect URLs and a tested confirmation flow. Waitlist offers appear in the application; no email alerts or payment processing are implemented.

Expired holds are processed when application requests run database upkeep. The client refreshes while open; expiry processing does not require a continuously running background worker. Free-tier hosting limits and inactivity pauses may affect availability.
