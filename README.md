# SeatLock

Campus event reservations with timed holds, fair waitlists, organizer tools and a concurrency demonstration.

Live: https://seatlock-roan.vercel.app

## Stack
Next.js App Router, React, TypeScript, Supabase Auth and PostgreSQL, Vercel Hobby.

## Features
Discover/search/filter/sort events; create/edit/cancel events; five-minute seat holds; confirmation and cancellation; FIFO waitlist promotion; expiry handling; personal tickets; calendar exports; organizer attendee lists; CSV exports; check-in; an isolated 80-request reliability lab.

## Development
Node.js 22 or newer. Run `npm ci`, then `npm run dev`. Production verification: `npm run build` and `npm run typecheck`.

The Supabase URL and publishable key in `lib/supabase.ts` and `app/api/seatlock/route.ts` are public client configuration, not privileged keys. For another Supabase project replace both. Never commit service-role keys, passwords or access tokens.

## Database
Apply `supabase/001_seatlock.sql` once to a fresh Supabase database. Direct table access is blocked by RLS and privilege revocation. Authenticated RPC functions derive identity from the verified JWT, enforce organizer ownership, and serialize reservation mutations in transactions. No browser-supplied user ID is trusted. The global transaction lock prioritizes correctness for this small campus application; higher traffic would benefit from narrower locks and separate read/maintenance transactions.

`supabase/test-booking.sql` runs rollback-only checks against a test database. The production migration has already been applied to the configured project. Do not reapply the initial schema there.

## Authentication
Email/password signup is enabled. Email confirmation is disabled for this portfolio demo, so users can create an account and sign in immediately. Email ownership is not verified. This setting was checked against the live Supabase Auth settings on 4 November 2026.

For verified email signup, configure custom SMTP, set the Site URL and allowed redirect URL to https://seatlock-roan.vercel.app, then enable email confirmation and test email delivery. Supabase's built-in email service is restricted; delivery to arbitrary public users has not been verified.

Password login and booking workflows were tested with an isolated confirmed test user. No payment or paid upgrade is required by the application. Free-tier quotas and inactivity pauses still apply.

## Deployment
Import this repository into Vercel using the Next.js preset. Install: `npm ci`. Build: `npm run build`. The project does not require private environment variables. The existing Vercel project is connected to CodeWith-Pranav/SeatLock. Pushes to main trigger production deployments; pull requests receive preview deployments. GitHub Actions runs the production build and TypeScript checks.

## Migration notes
This version replaces Cloudflare D1 and platform sign-in with PostgreSQL and Supabase email/password sign-in while retaining the original UI and booking features. Existing records on the previous ChatGPT-hosted database have not been copied. Do not delete the old deployment if its records need preservation; export/migrate them first.
