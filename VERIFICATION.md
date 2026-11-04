# Verification — 4 November 2026

- Fresh signup returns a session, and password login succeeds for two disposable accounts.
- Live API checks passed create, reserve, duplicate prevention, capacity, waitlist promotion, confirm, organizer authorization, check-in, attendee list, cancellation and event closure.
- Live reliability lab: 80 requests, 10 accepted, 70 capacity rejections, 0 errors, 0 oversold seats.
- Rollback-only SQL checks cover expiry, ownership, lab capacity and rejection of deleted account subjects.
- Review fixes refresh time after the booking lock and serialize reliability test starts per user.
- The old confirmed reservation was restored to its matching email account. The old rows have a separate private backup.

Security: email ownership is deliberately unverified in this portfolio demo. No SMTP verification or email alerts are claimed. Authenticated SECURITY DEFINER RPC functions are intentional: they check identity and organizer ownership; direct table privileges are revoked and RLS is enabled. The global booking lock favors correctness over high throughput. Automated tests do not cover every browser, accessibility behavior or dynamic Python program.
