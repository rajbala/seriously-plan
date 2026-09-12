# Product and architecture

## Product model

Seriously is a dashboard for protected developer and infrastructure resources.
Users configure providers such as GitHub, Codex, Claude Code, GitLab, and AWS,
then assign views to browsers or dedicated kiosk displays.

The system has four concepts:

- **Hub**: configuration, authentication, normalized data, history, and UI.
- **Provider**: a server-side integration with a protected resource.
- **Collector**: an optional workstation agent that submits selected local
  activity, such as Codex or Claude Code session status.
- **Display**: a read-only enrolled browser or kiosk assigned to dashboards.

```text
GitHub / GitLab / AWS ---- provider ----+
                                        |
Codex / Claude Code ---- collector ---- Hub ---- browser
                                        |
                                        +-------- Cage display
```

## Runtime stack

- TypeScript on an active Node.js LTS release
- React Router v7 Framework Mode
- React route loaders/actions and resource routes
- Web Fetch, Streams, and Crypto APIs
- SQLite for local deployments
- D1 for Cloudflare deployments
- SQL-backed jobs, webhook inbox, and change-event log
- Server-Sent Events (SSE), with reconnect cursors and conditional-polling
  fallback
- pnpm workspaces, Vitest, and Playwright
- OCI image for conventional self-hosting

The open product supports both Node/SQLite and single-tenant Workers/D1. The
private hosted product runs on Workers/D1.

## Portability boundary

Domain, UI, and provider code depend on injected capabilities:

```ts
interface PlatformServices {
  database: Database;
  secrets: SecretStore;
  jobs: JobScheduler;
  events: EventNotifier;
  crypto: CryptoProvider;
  clock: Clock;
}
```

They do not import SQLite drivers, D1 bindings, `node:fs`, child processes, or
Cloudflare-specific APIs. Deployment adapters may use those facilities.

The portable substrate is:

- a Web `Request`/`Response` runtime;
- outbound HTTPS;
- Web Crypto;
- persistent SQLite-compatible SQL;
- environment-provided secrets; and
- a mechanism that periodically invokes an authenticated maintenance handler.

Durable Objects, KV, R2, Queues, and Workflows are not architectural
dependencies.

## Data and job model

Provider data is normalized into typed records and events. Provider plugins do
not own UI markup or receive unrestricted database access.

Scheduled work and webhook deliveries are durable SQL rows. Workers claim a
bounded number with expiring leases. Work is idempotent and resumable. The same
job logic can be invoked by a systemd timer, cron, or Cloudflare Cron Trigger.

Every dashboard-affecting transaction appends a monotonically ordered change
event. SSE clients reconnect with `Last-Event-ID`. A persistent Node server can
wake its in-memory listeners immediately; a stateless runtime can check the SQL
event log while the SSE response remains open. Correctness never depends on an
in-memory notification.

## Provider model

The provider SDK exposes metadata, configuration and credential schemas,
health, synchronization, and optional actions. Providers receive scoped HTTP,
secret, cursor, record, and logging capabilities.

Supported provider forms:

1. Bundled, reviewed TypeScript providers that run on Node and Workers.
2. Remote HTTPS collectors/providers using a versioned protocol.
3. Optional local subprocess providers for Node only, never the universal
   plugin contract.

GitHub is the first remote provider. Codex and Claude Code begin as collectors
because their useful state typically originates on developer workstations.
Collectors do not upload prompts, source, terminal output, or conversation
content by default.

## Authentication and secrets

Identity classes remain separate:

- users administer an installation;
- displays can only read assigned dashboards;
- collectors can only submit allowed record kinds;
- providers have narrowly scoped external credentials.

Provider secrets are encrypted before storage using a master key supplied by
the deployment. Displays never receive provider credentials. Display enrollment
uses a short-lived code approved from an authenticated administrative browser.

## Hosted tenancy

The public Hub models one installation. The private hosted Worker resolves an
authenticated tenant and constructs tenant-scoped repositories before entering
shared domain and route code.

Hosted D1 tables include `tenant_id` in primary keys, foreign keys, uniqueness
constraints, cache keys, jobs, and change events. Hosted request code cannot
obtain a raw D1 binding. Cross-tenant operations use separate private operational
interfaces and authentication.

The hosted edition starts with one shared D1 database and may later use a fixed
set of D1 shards. Database-per-customer and platform-specific coordination are
not required for the initial service.

## Deployment shapes

```text
Self-hosted VM/LXC:  React Router Node server + SQLite
Self-hosted edge:    React Router Worker + D1, one installation
Hosted service:      private React Router Worker + tenant-scoped D1
Lenovo appliance:    Cage/Chromium display enrolled with either Hub
```
