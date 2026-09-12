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
Password canaries prove only unique salts and policy-compliant Argon2id
verifiers are stored on both adapters; login, migration, parameter upgrade, and
malformed-verifier tests fail safely. Account, source, and global login limits
bound guessing and Argon2id work without permanent lockout. Session tests require
rotation at login, production `Secure`, `HttpOnly`, host-only and appropriate
`SameSite` cookies, and no credentials in URLs or Web Storage. Concurrent
removal, self-demotion, and transfer preserve at least one standalone owner
atomically on SQLite and D1.
Enrollment tests prove an approved human-readable code cannot redeem without
the initiating display's separate high-entropy device secret. A restore racing
with mutations and leased jobs advances an external generation and rejects every
pre-restore commit on both adapters.

Removal and demotion races prove every already-authorized privileged mutation
rechecks its user/membership generation at commit. Backups taken during writes
or a simulated crash restore one complete pre-write or post-write point on
SQLite and D1, including WAL-visible and cross-table state, never a torn mix.

Backup authentication tests reject truncation, byte or metadata substitution,
cross-installation replay, and structurally valid row tampering before replacing
live state. Restore tests prove old password and WebAuthn credentials cannot mint
a session until installer-authenticated recovery establishes new owner
credentials. Clock-driven tests enforce administrative idle and absolute session
deadlines, rotation on renewal, and recent-authentication bounds on both runtimes.
WebAuthn fixtures reject reused or expired challenges, wrong RP IDs and origins,
wrong ceremony types, absent required presence or verification, bad signatures,
and counter rollback according to the cloned-authenticator policy.

DEK-rotation fault tests race writes and crashes through every rotation phase on
SQLite and D1; no old-generation ciphertext can commit after cutover or become
unreadable when the retired key is destroyed.

Independent session-revocation races prove an in-flight privileged mutation
cannot commit under a revoked or rotated session even while its user and role
remain active. Raw standalone backup fixtures reveal no user data, password
verifiers, dashboards, provider records, or event history without separately
held recovery material.
Recovery-package fixtures reject Argon2id parameters below the versioned memory,
iteration, or calibrated-time floor, or above memory, iteration, parallelism,
salt, and metadata ceilings, before allocation or derivation.

The cross-origin and missing, malformed, or mismatched CSRF-token matrix covers
every session-authenticated state-changing route on both deployments, including
dashboard, display, user, secret, provider, collector, action, import, export,
backup, restore, and installation-setting operations.

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
Outbound broker fixtures reject private, loopback, link-local, metadata, rebound,
and redirect-switched destinations unless a separately approved private-network
capability applies. Slow streams, excessive redirects, encoded or decoded byte
overruns, and compression bombs terminate within resource bounds on both
deployments without a partial checkpoint.
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

HTTP maintenance triggers require narrow, revocable, hashed credentials and are
rate bounded. Request-level tests for systemd/cron and Worker shapes reject
missing, invalid, revoked, expired, and incorrectly scoped credentials without
claiming work.

## Phase 3 — live displays

**Outcome:** healthy clients receive updates without polling.

- Durable SQL change-event log.
- SSE resource route, heartbeats, cursors, and reconnect replay.
- Public `ChangeNotifier` contract and loss/duplication/order contract suite.
- Immediate in-process and explicit database-poll adapters.
- Durable Object notifier as the first hosted adapter, partitioned by organization
  or documented shard and containing no authoritative state.
- SQL outbox checks after every hint, timeout, and reconnect.
- Conditional-polling fallback and offline/reconnect UX.
- Event retention and compaction with an explicit oldest-retained cursor and
  full-snapshot reconciliation for stale or invalid cursors.
- Periodic authorization and assignment revalidation for already-open streams.
- Per-credential, per-installation or tenant, and deployment-wide connection
  limits plus bounded per-stream queues and slow-consumer deadlines.

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
Clock-driven tests prove expiry, revocation, and reassignment close an existing
stream within 60 seconds on both deployments. Well-formed future and
wrong-dashboard or wrong-generation cursors force a scoped snapshot instead of
suppressing updates.
Compaction races prove retention-floor validation and replay are atomic or detect
a noncontiguous first sequence and force a scoped snapshot.
Notifier contract tests drop, duplicate, delay, and reorder signals and restart
the adapter while proving identical eventual state. Configuration explicitly
selects the notifier; unavailable configured adapters fail observably instead of
silently switching transports. Database-poll mode uses bounded jitter and an
indexed sequence query, while the Lenovo maintains one SSE connection rather
than polling resources itself.
Connection-flood and non-reading-client fixtures prove both runtimes cap streams,
queued bytes, file descriptors, and backpressure duration without affecting
healthy displays.

## Phase 4 — Codex and Claude Code collectors

**Outcome:** users can see selected coding-agent activity without exposing work
content by default.

- Versioned collector enrollment and ingestion protocol.
- Narrow, revocable collector credentials.
- Codex collector and session-status widgets.
- Claude Code collector using the same normalized model.
- Provider-neutral work-session, usage-aggregate, and activity-event schemas.
- Declarative attention rules for needs-input, failure, staleness, and usage
  thresholds, with acknowledged and resolved lifecycle.
- Explicit privacy controls and redaction tests.
- Collector health and last-seen status.
- Collector-scoped idempotency keys and monotonic sequence handling.
- Opt-in aggregate token metering and signed self-hosted leaderboard reporting.

**Exit gate:** a workstation can report session state to either deployment; no
prompt, source, terminal output, or transcript is transmitted by default.
Duplicate and out-of-order submissions cannot regress state. Expired or revoked
credentials, collector identity substitution, and unsupported record kinds are
rejected on both deployments.

Collector streams have byte and read-time limits, bounded batch counts,
per-collector request rates, and configurable standalone retention/storage
ceilings. Both adapters reject oversized, slow, over-batch, over-rate, and
over-retention submissions without partial ingestion.

Leaderboard tests prove reporting is disabled by default; payload previews and
captured traffic contain only consented aggregates; signatures, sequences,
idempotency, correction windows, revocation, deletion, rate limits, and hostile
payloads are enforced. Hosted, provider-verified, and self-reported entries are
visibly distinct, and estimated spend identifies its versioned price snapshot.

## Phase 5 — hosted private beta

**Outcome:** customers can create organizations, collaborate with scoped roles,
and use an isolated, metered Workers/D1 service.

- Global hosted user identity and organization-as-tenant model.
- Passkey-first hosted authentication with verified-email bootstrap and delayed
  recovery, multiple authenticators, session revocation, and step-up gates.
- Organization creation, switching, invitations, and deletion lifecycle.
- Capability-based `owner`, `admin`, `member`, and `viewer` authorization.
- Membership removal, session revocation, ownership transfer, and last-owner
  protection.
- Tenant-scoped hosted repositories and composite schema constraints.
- Per-tenant encryption derivation.
- Stripe billing at USD $5 per billable person per month, versioned seat counts,
  webhook reconciliation, grace, suspension, and deletion separation.
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

Hosted authentication tests cover passkey enrollment and multiple credentials;
email-link expiry, replay, verifier storage, and rate limits; delayed recovery
notifications; session invalidation; mandatory new-passkey registration; and
recent-authentication enforcement across all organizations belonging to one
identity. Social identity failure cannot block recovery.

Billing tests calculate one seat per distinct active human organization member,
exclude invitations and machine identities, and cover joins, removals,
cross-organization membership, proration, cancellation, failed payment, grace,
and suspension. Exact-raw-body Stripe signature tests, duplicate and reordered
webhooks, missed-webhook reconciliation, stale browser redirects, and concurrent
seat changes cannot create incorrect entitlements. Billing failure never invokes
tenant deletion or purge.

Suspending or deleting an organization rejects every user and machine request
boundary and prevents already-leased jobs and in-flight non-job mutations from
committing or publishing responses under the prior lifecycle generation.
Collector ingestion, provider callbacks, administration, exports, and streams
are raced against both transitions. Each enforced quota
has below-limit, at-limit, over-limit, concurrent-consumption, and background-job
tests; exhausting tenant A cannot deny service to tenant B. Operations tests
cover every support capability, revocation, explicit tenant targeting, customer
session rejection, insufficient operations privilege, step-up requirements, and
audit creation. Clock-driven deletion tests prove recovery during retention and
irreversible purge afterward, including customer data, secrets, exports, and
recoverable backups, while validating the documented non-secret audit or legal
exceptions.

Restoring a shared D1 snapshot from before a completed purge cannot unwrap or
recover the tenant because the external key authority retains a non-rollbackable
tombstone; this is tested after the retention deadline.

A hosted export restored into the public edition invokes the installer-bound
local-owner bootstrap, imports no hosted identity or membership table, rejects
all hosted sessions and machine credentials, reissues scoped local credentials,
and proves the migrated dashboards and decrypted provider configuration are
administrable.

Operations audit tests prove append-only enforcement at repository and storage
boundaries: update/delete attempts fail for support identities, destructive
operations, tenant purge, and retention jobs, while linked corrections preserve
the original record and tamper evidence verifies. Rewritten and internally
re-chained D1 snapshots, including alteration of the newest record, fail against
per-commit externally sequenced authenticated receipts. Authority outage and
disaster-recovery tests fail destructive actions closed and reject rollback of
its generation. Step-up tests enforce a five-minute,
single-use assertion bound to actor, capability, target, request, and reason and
reject stale, replayed, or substituted assertions.

Fault injection at every audit prepare, intent, finalize, and apply boundary
proves retries are idempotent, destructive state is never applied without its
final receipt, reservations can be aborted, and finalized-but-unapplied intents
are recoverable without unexplained sequence gaps.

Restore tests quarantine all externally mutating jobs and permit execution only
after durable idempotency proof or reconciliation using non-rollback evidence.
Dispatch races prove an action intent's generation-checked claim is ordered with
session, membership, and tenant revocation before any provider request is sent.
Authority-outage and concurrent-purge tests prove encrypted customer access
fails closed rather than using stale key status.
Pre-removal and pre-suspension D1 snapshots cannot restore membership or tenant
access because external authorization generations reconcile before reopening.
Restoring a snapshot predating finalized audit receipts replays their canonical
records from the authority before operations resume.

Raw pre-purge snapshot inspection proves all purge-sensitive tenant rows are
ciphertext and remain unrecoverable after the external tombstone. Leaderboard
tests delete reports from closed periods from retained and public views without
allowing score replacement or reopening the bucket.
Pre-deletion leaderboard snapshots remain deleted after hosted restore because
external report tombstones are applied before retained or public reads.
Leaderboard reads during an authority outage after such a restore fail closed
and never expose an alias or report whose deletion cannot be disproved.

DEK-rotation races cover every tenant-encrypted write path, including dashboards,
records, events, jobs, and exports; no retiring-generation ciphertext commits
after cutover.

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
quality gates without importing Hub internals. A hostile local-process extension
cannot read Hub data, inherited environment or recovery keys, escape its
filesystem, identity, or resource limits, or contact undeclared network
destinations; hosts lacking the required sandbox reject local-process
installation.

A malicious community widget cannot access Hub DOM, cookies, storage, APIs, or
undeclared networks from its separate-origin sandbox. Declarative widgets and
the schema-validated message bridge expose only manifest-granted data/actions.

The north-star command-center scenario passes end to end with GitHub, Codex,
Claude Code, Cloudflare, and a host collector, then substitutes a community
connector that drives the same generic widgets without core changes.

## Deferred until justified

- Durable Objects or another proprietary primitive as authoritative state or a
  required public dependency
- microservices
- Redis or NATS as a required service
- arbitrary in-process third-party code
- a plugin marketplace
- PostgreSQL
- multi-region writes
- native mobile applications
