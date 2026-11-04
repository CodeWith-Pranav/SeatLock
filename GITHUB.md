# Put SeatLock on your GitHub

1. Extract this ZIP. Open the inner seatlock folder, which contains package.json.
2. Create an empty GitHub repository named seatlock. Do not initialize it with another README.
3. In this folder, run:

```sh
git init
git add .
git commit -m "Add SeatLock event booking application"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/seatlock.git
git push -u origin main
```

Replace YOUR_USERNAME with your actual GitHub username. Authenticate through GitHub's supported Git flow when prompted; do not put tokens in source files or commands.

Suggested repository description:
Campus event booking with timed holds, fair waitlists, organizer tools and atomic capacity checks.

Set the repository Website field to the live URL or your custom domain once configured. Pin the repository to your profile if desired.

The included .gitignore excludes dependencies, local runtime files and secrets. Do not force-add .env, node_modules, .wrangler, .sites-runtime or dist. The supplied .openai/hosting.json describes the existing deployment; it contains a project identifier, not an API credential. Publishing this repository does not grant control of that deployment.

Tests measured in the original development environment: 10 SQLite lifecycle/concurrency checks passed; in-browser D1 race accepted 10 of 80 requests, rejected 70 and oversold zero seats. Do not claim that this proves large-scale production throughput. The provided API script was not executable against the managed preview network and is not reported as passed.

Be accurate about your contribution. The initial implementation was AI-assisted; study and extend the code, keep meaningful commits, and explain the features you understand and changes you made.

Third-party notices in scripts/vite and vendor must be retained. No blanket license is assigned to bundled third-party dependencies; consult their own licenses before redistribution.
