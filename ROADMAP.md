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
- Build a minimal Node/SQLite self-hosted app.
- Build a minimal single-tenant Workers/D1 app.
- Publish a versioned public package consumed by `seriously-cloud`.
- Scaffold the private Worker without copying public source.
- Add CI, dependency review, secret scanning, SBOM, and Codex PR review.

**Exit gate:** one public page and health resource route run from Node/SQLite and
Workers/D1; the private Worker consumes a pinned public package; clean public CI
has no access to private source.

## Phase 1 — useful standalone dashboard

**Outcome:** a self-hosted user can configure and display persisted dashboards.

- Installation bootstrap and first administrator.
- Session authentication and CSRF protection.
- Dashboard and widget CRUD.
- Responsive display route with kiosk presentation mode.
- Display enrollment, revocation, and dashboard assignment.
- Encrypted secret store and key-rotation groundwork.
- Backup, restore, export, and import.

**Exit gate:** a fresh container installation can enroll a browser, survive a
restart, restore from backup, and expose no administrative capability through a
display credential.

## Phase 2 — provider platform and GitHub

**Outcome:** the first protected integration produces useful live dashboard
data.

- Versioned provider SDK and contract-test kit.
- Provider configuration and credential schemas.
- Normalized records, cursors, health, and synchronization.
- SQL job leases, retries, and authenticated maintenance invocation.
- GitHub App authentication with least privilege.
- Polling reconciliation; verified webhook inbox where externally reachable.
- Pull-request, issue, repository, and workflow-run widgets.

**Exit gate:** disconnects, duplicate webhooks, token revocation, and retries are
covered by tests; a GitHub workflow change appears on an enrolled display.

## Phase 3 — live displays

**Outcome:** healthy clients receive updates without polling.

- Durable SQL change-event log.
- SSE resource route, heartbeats, cursors, and reconnect replay.
- Immediate in-process notifier for the Node deployment.
- SQL event checks for stateless deployments.
- Conditional-polling fallback and offline/reconnect UX.
- Event retention and compaction.

**Exit gate:** a display misses no update across Wi-Fi loss, Hub restart, Worker
replacement, or event replay, and recovers without user intervention.

## Phase 4 — Codex and Claude Code collectors

**Outcome:** users can see selected coding-agent activity without exposing work
content by default.

- Versioned collector enrollment and ingestion protocol.
- Narrow, revocable collector credentials.
- Codex collector and session-status widgets.
- Claude Code collector using the same normalized model.
- Explicit privacy controls and redaction tests.
- Collector health and last-seen status.

**Exit gate:** a workstation can report session state to either deployment; no
prompt, source, terminal output, or transcript is transmitted by default.

## Phase 5 — hosted private beta

**Outcome:** invited customers can use an isolated, metered Workers/D1 service.

- Tenant identity, membership, and lifecycle.
- Tenant-scoped hosted repositories and composite schema constraints.
- Per-tenant encryption derivation.
- Billing, plans, quotas, suspension, and deletion.
- Managed backup/export and hosted-to-self-hosted migration.
- Operational audit log and separately authenticated support console.
- Two-tenant adversarial isolation suite for every repository.

**Exit gate:** automated tests demonstrate tenant isolation; a hosted tenant can
export and restore into the open self-hosted edition; billing failure cannot
erase or expose customer data.

## Phase 6 — appliance integration and public launch

**Outcome:** the Lenovo image becomes an enrollable Seriously display and the
projects are supportable by new users.

- Replace the Lenovo proof page with the display enrollment client.
- Add first-boot Wi-Fi and Hub selection UX without embedding credentials.
- Pin and verify a released Seriously display artifact in the Lenovo build.
- Publish installation, threat-model, privacy, backup, and recovery guides.
- Establish version support, vulnerability reporting, and release cadence.

**Exit gate:** a new user can deploy a Hub, connect GitHub, enroll a Lenovo, and
recover both Hub and display using only published documentation.

## Deferred until justified

- Durable Objects or another proprietary coordination primitive
- microservices
- Redis or NATS as a required service
- arbitrary in-process third-party code
- a plugin marketplace
- PostgreSQL
- multi-region writes
- native mobile applications
