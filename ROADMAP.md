# Delivery roadmap

Each phase is delivered through small pull requests and must pass its exit gate
before the next phase becomes the primary focus.

## Phase 0 — foundations and contracts

**Outcome:** both implementation repositories have reproducible builds and a
tested public/private dependency boundary.

- Decide license and contribution policy for `seriously`.
- Scaffold React Router v7, TypeScript, pnpm, linting, Vitest, and Playwright.
- Establish public package boundaries and server/client import rules.
- Define domain IDs, clock, crypto, database, secret, and job contracts.
- Establish purpose-specific database ports and one SQLite/D1 contract suite.
- Establish canonical wire schemas and monorepo-managed client SDK packages.
- Define extension manifests, capability boundaries, scaffold tooling, local
  harness, conformance tests, and the machine-readable quality checklist.
- Build a minimal Node/SQLite self-hosted app.
- Build a minimal single-tenant Workers/D1 app.
- Publish a versioned public package consumed by `seriously-cloud`.
- Scaffold the private Worker without copying public source.
- Add CI, dependency review, secret scanning, SBOM, and Codex PR review.

**Exit gate:** one public page and health resource route run from Node/SQLite and
Workers/D1; the private Worker consumes a pinned public package; clean public CI
has no access to private source. Import-boundary and artifact checks enforce the
engineering standards; SQLite and D1 pass the same initial database contracts;
generated/shared SDK validators pass cross-version fixtures; and a scaffolded
reference extension passes its conformance and quality gates.

## Phase 1 — useful standalone dashboard

**Outcome:** a self-hosted user can configure and display persisted dashboards.

- Installer-bound, single-use installation bootstrap and first administrator.
- Installation-level owner, admin, member, and viewer capability roles;
  identity-bound, expiring, atomic invitations; removal; and session revocation.
- Session authentication and CSRF protection.
- Dashboard and widget CRUD.
- Responsive display route with kiosk presentation mode.
- Display enrollment, revocation, and dashboard assignment.
- Encrypted secret store, key rotation, and a documented master-key recovery
  procedure.
- Backup, restore, export, and import.

**Exit gate:** the complete enrollment, persistence, authorization, restart,
backup, and restore flow passes against both Node/SQLite and Workers/D1. A
restored installation can decrypt a seeded secret after its master key is
securely reintroduced. Envelope-encryption tests on both adapters cover OAuth
tokens, API keys, private keys, tampering, nonce uniqueness, context-bound
cross-installation substitution, KEK rewrapping, DEK rotation, unknown key
versions, and fail-closed recovery without key material. Concurrent, reused,
expired, and unapproved enrollment codes fail to issue credentials. With two
dashboards, a display credential can read only its assignment through loaders
and resource routes and has no administrative capability. An unauthenticated
attacker cannot claim a reachable fresh installation: attacker-first, replay,
and concurrent first-administrator requests prove the installer-generated
bootstrap capability is consumed
atomically and the claim endpoint is permanently disabled afterward. A second
user can be invited, receives only the assigned installation capabilities, and
loses both new and active-session access when removed. Request-level allow/deny
tests cover every standalone role capability on both adapters. Wrong-identity,
expired, replayed, and concurrently redeemed invitations fail. Restoring an old
backup advances the authentication epoch: all pre-restore sessions and machine
credentials remain rejected and new credentials are explicitly issued on both
adapters. Database and backup canaries prove raw session, display, collector,
invitation, callback-state, and other bearer values are never stored.
Cross-origin and missing, malformed, or mismatched CSRF-token
requests cannot mutate dashboards, displays, users, or secrets on either
deployment.

## Phase 2 — provider platform and GitHub

**Outcome:** the first protected integration produces useful live dashboard
data.

- Versioned provider SDK and contract-test kit.
- Provider configuration and credential schemas.
- Normalized records, atomic synchronization checkpoints, cursors, health, and
  failure injection between checkpoint operations.
- SQL job leases with fencing tokens, retries, and authenticated maintenance
  invocation.
- GitHub App authentication with least privilege.
- Polling reconciliation; verified webhook inbox where externally reachable.
- Pull-request, issue, repository, and workflow-run widgets.

**Exit gate:** SQLite and D1 tests cover atomic record/cursor/event checkpoints,
idempotent upserts, disconnects, duplicate webhooks, token revocation, bounded
backoff, terminal failures, maximum attempts, dead-lettering, and two workers
racing across lease expiry; stale fencing tokens cannot commit. Valid webhook
signatures over the exact raw bytes enqueue once, while missing, malformed, and
body-mismatched signatures enqueue nothing. Oversized and slow raw bodies are
terminated under byte, time, and unauthenticated rate limits without enqueueing.
Authorization callback tests reject expired, replayed, session-mismatched,
installation/tenant-mismatched, and configuration-mismatched state on both
adapters. Multi-page fixtures cover every GitHub record kind and deletion from a
later page. CI rejects any GitHub App
permission outside the documented read-only allowlist. With webhooks suppressed,
scheduled polling discovers updates and deletions. Polling and webhook jobs that
start from the same provider state cannot commit out of generation order on
SQLite or D1. Indeterminate external actions reconcile or require an audited
decision and are never automatically retried without enforceable idempotency. A
seeded canary private key and token never appear in any administrative or display
HTML, loader, action, JSON, error, log, event, diagnostics, telemetry, or export
path that can touch provider configuration. Hostile provider fixtures include
HTML, SVG, event handlers, Markdown, and unsafe URL schemes and execute in
neither administrative nor display views. The complete GitHub authorization-
through-workflow-change-to-display scenario passes against both Node/SQLite and
Workers/D1.

## Phase 3 — live displays

**Outcome:** healthy clients receive updates without polling.

- Durable SQL change-event log.
- SSE resource route, heartbeats, cursors, and reconnect replay.
- Immediate in-process notifier for the Node deployment.
- SQL event checks for stateless deployments.
- Conditional-polling fallback and offline/reconnect UX.
- Event retention and compaction with an explicit oldest-retained cursor and
  full-snapshot reconciliation for stale or invalid cursors.
- Periodic authorization and assignment revalidation for already-open streams.

**Exit gate:** a display misses no state change across Wi-Fi loss, Hub restart,
Worker replacement, ordinary replay, or reconnection from a cursor older than
retention. A write concurrent with stale-client snapshot creation is represented
by the consistent snapshot or replayed after its returned high-water mark, never
neither. Revoking a credential or changing its dashboard assignment stops an
already-open stream without waiting for the client to reconnect. Two-dashboard
tests prove that snapshot and SSE access remain assignment-scoped.

With SSE disabled or broken, conditional polling on both deployments handles
unchanged validators, concurrent updates, authorization or assignment changes,
and recovery to streaming without missing or exposing state.

## Phase 4 — Codex and Claude Code collectors

**Outcome:** users can see selected coding-agent activity without exposing work
content by default.

- Versioned collector enrollment and ingestion protocol.
- Narrow, revocable collector credentials.
- Codex collector and session-status widgets.
- Claude Code collector using the same normalized model.
- Explicit privacy controls and redaction tests.
- Collector health and last-seen status.
- Collector-scoped idempotency keys and monotonic sequence handling.
- Opt-in aggregate token metering and signed self-hosted leaderboard reporting.

**Exit gate:** a workstation can report session state to either deployment; no
prompt, source, terminal output, or transcript is transmitted by default.
Duplicate and out-of-order submissions cannot regress state. Expired or revoked
credentials, collector identity substitution, and unsupported record kinds are
rejected on both deployments.

Leaderboard tests prove reporting is disabled by default; payload previews and
captured traffic contain only consented aggregates; signatures, sequences,
idempotency, correction windows, revocation, deletion, rate limits, and hostile
payloads are enforced. Hosted, provider-verified, and self-reported entries are
visibly distinct, and estimated spend identifies its versioned price snapshot.

## Phase 5 — hosted private beta

**Outcome:** customers can create organizations, collaborate with scoped roles,
and use an isolated, metered Workers/D1 service.

- Global hosted user identity and organization-as-tenant model.
- Organization creation, switching, invitations, and deletion lifecycle.
- Capability-based `owner`, `admin`, `member`, and `viewer` authorization.
- Membership removal, session revocation, ownership transfer, and last-owner
  protection.
- Tenant-scoped hosted repositories and composite schema constraints.
- Per-tenant encryption derivation.
- Billing, plans, quotas, suspension, and deletion.
- Managed backup/export and hosted-to-self-hosted migration.
- Operational audit log and separately authenticated support console.
- Two-tenant adversarial isolation suite for every repository.
- Request-boundary isolation tests for users, displays/SSE, collectors, provider
  callbacks, and webhooks.

**Exit gate:** automated tests demonstrate tenant isolation; a hosted tenant can
export and restore into the open self-hosted edition; billing failure cannot
erase or expose customer data. A tenant-A identity cannot select tenant B using
any hostname, slug, route, query, header, body, or conflicting tenant hint. A
user can create and switch organizations and hold different roles in each.
Single-use, expiring, identity-bound invitations and all role transitions are
tested. Request-level allow/deny tests cover every capability in the documented
role matrix, including one user with different roles across organizations and
attempts to grant capabilities the actor lacks. Removal terminates existing
access. Concurrent leave, removal, demotion, and transfer requests preserve at
least one owner on D1.

Suspending or deleting an organization rejects every user and machine request
boundary and prevents already-leased jobs from committing. Each enforced quota
has below-limit, at-limit, over-limit, concurrent-consumption, and background-job
tests; exhausting tenant A cannot deny service to tenant B. Operations tests
cover every support capability, revocation, explicit tenant targeting, customer
session rejection, insufficient operations privilege, step-up requirements, and
audit creation. Clock-driven deletion tests prove recovery during retention and
irreversible purge afterward, including customer data, secrets, exports, and
recoverable backups, while validating the documented non-secret audit or legal
exceptions.

Operations audit tests prove append-only enforcement at repository and storage
boundaries: update/delete attempts fail for support identities, destructive
operations, tenant purge, and retention jobs, while linked corrections preserve
the original record and tamper evidence verifies.

## Phase 6 — appliance integration and public launch

**Outcome:** the Lenovo image becomes an enrollable Seriously display and the
projects are supportable by new users.

- Replace the Lenovo proof page with the display enrollment client.
- Add first-boot Wi-Fi and Hub selection UX without embedding credentials.
- Pin and verify a released Seriously display artifact in the Lenovo build.
- Publish installation, threat-model, privacy, backup, and recovery guides.
- Establish version support, vulnerability reporting, and release cadence.
- Publish and enforce the extension manifest, scaffold, conformance kit, quality
  checklist, managed SDK support policy, and database adapter contract.

**Exit gate:** a new user can deploy a Hub, connect GitHub, enroll a Lenovo, and
recover both Hub and display using only published documentation. Release-upgrade
tests start from every supported prior version on Node/SQLite and Workers/D1 and
preserve dashboards, encrypted credentials, sessions subject to authentication
epoch policy, jobs, extension configuration, and protocol compatibility. Each
adapter has an exercised rollback or roll-forward recovery procedure. A new
community provider and widget built from the scaffold pass the conformance and
quality gates without importing Hub internals.

## Deferred until justified

- Durable Objects or another proprietary coordination primitive
- microservices
- Redis or NATS as a required service
- arbitrary in-process third-party code
- a plugin marketplace
- PostgreSQL
- multi-region writes
- native mobile applications
