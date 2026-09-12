# Pull-request and Codex review process

All implementation and planning changes are made on short-lived branches and
merged through pull requests. A passing build is necessary but not sufficient:
the author, automated checks, and reviewer must establish that the change meets
its stated acceptance criteria.

## Pull-request size and content

A PR should produce one reviewable outcome. Separate scaffolding, domain
contracts, database adapters, providers, UI behavior, and deployment changes
unless they are inseparable for an executable vertical slice.

Every PR description includes:

- problem and user-visible outcome;
- scope and explicit non-goals;
- architecture or security implications;
- test evidence;
- migration and rollback behavior;
- public/private boundary impact; and
- follow-up work.

Use the template in `.github/pull_request_template.md`.

## Required checks

Planning PRs:

- Markdown links and formatting;
- decision consistency; and
- Codex review of ambiguity, missing failure modes, and unverifiable gates.

Public implementation PRs:

- formatting, lint, typecheck, unit, integration, and browser tests;
- Node/SQLite and Workers/D1 contract tests where applicable;
- server/client import-boundary validation;
- secret and dependency scanning;
- clean public-only build and artifact inspection;
- migration forward/restore testing; and
- Codex review.

Private implementation PRs:

- all applicable public-package compatibility tests;
- Workers/D1 integration tests;
- adversarial tenant-isolation tests using duplicate resource IDs;
- private-server-code browser-bundle scan;
- billing and lifecycle failure tests; and
- Codex review.

## Codex review policy

Request Codex review on every non-trivial PR after automated checks pass and
before merge. The review request should ask for findings rather than a summary,
prioritized by severity, with file/line references and specific failure
scenarios.

Review focus:

1. authentication, authorization, tenant isolation, and secret handling;
2. data loss, migration, concurrency, replay, and retry behavior;
3. divergence between SQLite and D1;
4. leakage across public/private and server/client boundaries;
5. provider and collector privacy;
6. missing tests for realistic failures; and
7. unnecessary platform coupling.

Suggested review instruction:

> Review this PR for correctness and security. Prioritize concrete findings over
> summary. Check authentication and tenant boundaries, SQLite/D1 behavioral
> parity, retry/idempotency, migrations and rollback, secret exposure,
> server/client bundling, and whether tests exercise the stated acceptance
> criteria. Cite exact files and lines and explain a reproducible failure mode.

Resolve each material finding with a fix, a documented design decision, or a
linked follow-up issue accepted by the maintainer. Re-run review after material
security or architecture changes.

Codex review complements rather than replaces maintainer review. OpenAI's
official Codex use cases include reviewing pull requests or local diffs for
security regressions.

## Merge policy

- Default branches are protected.
- Required checks must be current with the PR head.
- At least one maintainer approval is required.
- Unresolved high- or critical-severity findings block merge.
- Prefer squash merge with a descriptive conventional commit.
- Delete the branch after merge.
- Releases are built by CI from signed or protected tags, not developer
  worktrees.

