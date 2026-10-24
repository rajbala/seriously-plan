# Phase 2: provider platform and GitHub

## Goal and sequencing

Phase 2 turns the demo's GitHub feed into the first protected integration:
a versioned provider platform, a least-privilege GitHub App, scheduled and
webhook-driven synchronization, and GitHub widgets that work on Node/SQLite and
Workers/D1. The [roadmap](ROADMAP.md#phase-2--provider-platform-and-github)
keeps the phase's outcome, deliverables and exit gate; this document splits
them into reviewable slices, orders them, and maps every gate clause to the
slice that proves it.

Phase 2 becomes the primary focus after two things close:

1. the [Phase 1.5](MANAGED_UPDATES.md) exit gate; and
2. the personal connection onboarding slice the roadmap places next.

The Phase 1 exit gate also has one partial clause, G1, which needs real D1
export evidence. The G1 work closes it with a throwaway D1 database and needs
no persistent Worker. Slice 6 does need a deployed, externally reachable
Worker for webhook delivery, so slice 0 owns that deployment, and the G1
evidence's optional second tier reuses it. Phase 1 stays formally open until
G1 closes; the phase-order rule is not waived.

This phase is read-only toward GitHub. It adds no externally mutating provider
action, no hosted GitHub App, no organization connections and no change to
[ADR 0018](decisions/0018-operational-demo-sequencing.md)'s rule that demo
pieces count only where they meet a phase's stated deliverable.

## Starting point

The operational demo and Phase 1 left working but partial code in `seriously`.
Each slice below replaces or extends one of these rather than starting from
zero:

| Existing piece | Where | What Phase 2 still needs |
|---|---|---|
| Job leases with fencing, restore quarantine | `docs/durable-job-leases.md` | Dispatch, retry and backoff, dead-letter, maintenance triggers |
| Read-only GitHub GraphQL decoders and bounded poller | `@seriously/provider-github` | Issues, repositories, workflow runs, scheduling, persistence |
| Owner-triggered refresh through a local `gh` login | `docs/github-demo-controls.md` | GitHub App authentication; retire the `gh` path |
| Provider secret store with envelope encryption | `docs/provider-secrets.md` | Provider-scoped secret capability, GitHub key custody |
| Extension scaffold, reference provider, quality checks | `examples/reference-provider` | Versioned provider SDK and published conformance harness |
| TypeScript and Python display/collector SDKs | `packages/sdk-*`, `python/` | Official Go clients |
| Database-polled change notification | `hub-services` | Unchanged; Phase 3 owns live displays |

The demo's `gh` login and manual refresh are recorded substitutes, not partial
credit toward the GitHub App, webhook or broker deliverables.

## Reviewable slices

Each slice is one or more pull requests in `seriously` unless stated. Every new
session-authenticated route enters the request-level authorization and CSRF
matrices (`tests/route-csrf-matrix.test.ts`) in the PR that adds it, not in a
later sweep.

### 0. Deployed acceptance Worker

The owner deploys a persistent Cloudflare Worker and D1 database with a
public hostname through the guided deployment in `seriously`'s
`docs/portable-deployment.md`, and picks its name and hostname. Secrets and
environments stay with the owner; sessions only document the steps and
consume the result. The same Worker runs tier 2 of `docs/d1-export-evidence.md`
(the backup and restore journey on a real deployment), so one acceptance
Worker serves both that and Phase 2. Slice 6 later uses its hostname as the
webhook endpoint.

### 1. Provider SDK, checkpoints and contract-test kit

Publish a versioned provider SDK in the public package boundary: metadata,
closed configuration and credential schemas, health, synchronization and
optional actions, with scoped HTTP, secret, checkpoint and logging
capabilities. A checkpoint atomically commits idempotent record upserts,
deletions, the next cursor and the change event, compare-and-swapped against
the configuration's synchronization generation, on SQLite and D1. Provider
health records last success, last failure and staleness without advancing the
success timestamp on failure.

The contract-test kit injects failures between every checkpoint operation and
runs against both adapters. The reference provider is ported to the SDK and
passes it, so the kit is proven by a provider other than GitHub. The existing
GitHub poller is ported onto the SDK without new record kinds yet.

### 2. Job runtime and maintenance triggers

Extend the lease repository into a dispatcher: bounded exponential backoff
with jitter, a maximum attempt count, immediate terminal failure for invalid
configuration and revoked credentials, and an inspectable dead-letter state
that cannot starve newly eligible jobs. Two workers racing across lease expiry
must leave only the current fence able to commit.

Authenticated maintenance invocation runs the same job logic from a systemd
timer, cron or a Cloudflare Cron Trigger. HTTP triggers take narrow, revocable,
hashed credentials, are rate bounded, and reject missing, invalid, revoked,
expired and wrongly scoped credentials without claiming work.

GitHub stays read-only, so the indeterminate-outcome clause is proven with a
fixture provider in the contract-test kit: an action intent whose dispatch
fails after possible acceptance becomes `indeterminate` and reconciles through
a provider read or an audited decision, never a blind retry. This is the
precondition the lease document sets before any externally mutating job.

### 3. Outbound HTTP broker

All provider HTTP goes through one scoped broker on both deployments. It
rejects private, loopback, link-local, metadata, DNS-rebound and
redirect-switched destinations unless a separately approved private-network
capability applies, and it enforces connect, first-byte, idle-read and total
deadlines, encoded and decoded byte ceilings, bounded redirects and a
decompression-ratio limit. A broker failure never produces a partial
checkpoint. Slices 2 and 3 do not depend on each other and can be reviewed in
parallel.

### 4. GitHub App authentication and callback state (carries G24)

Replace the `gh` login with a GitHub App each installation registers for
itself through GitHub's App manifest flow, per
[ADR 0023](decisions/0023-per-installation-github-app.md). The versioned App
manifest declares only the read-only permissions the widgets need; CI fails on
any permission outside the documented allowlist. The manifest code exchange
and the installation setup redirect both carry authorization state that is
high entropy, expiring, single use, and bound to the initiating session,
installation and provider configuration.

The App private key and webhook secret go straight into the provider secret
store; installation access tokens are minted through the broker, held in
memory only, and never persisted. Token revocation or App uninstallation turns
synchronization terminal with a clear health status, not a retry loop.

This slice closes Phase 1's deferred **G24**: database and backup canaries
prove that raw callback-state values are never stored, alongside the callback
rejection tests in the gate below.

### 5. Scheduled polling reconciliation for every record kind

Extend the poller and normalization to repositories, pull requests, issues and
workflow runs, following every cursor, with deletion detected from a later
page. Polling runs as scheduled jobs through slice 2. With webhooks suppressed,
scheduled polling alone discovers updates and deletions. The demo's `gh`
executable settings and manual refresh are removed in this slice; refresh
becomes "schedule a poll now" through the same job path.

### 6. Verified webhook inbox

Webhook ingress authenticates the exact raw bytes before parsing or
enqueueing. Valid signatures enqueue once; missing, malformed and
body-mismatched signatures enqueue nothing. Oversized and slow bodies are cut
off under byte, time and unauthenticated source and global rate limits. Webhook
and polling jobs that start from the same provider state cannot commit out of
generation order on SQLite or D1.

Webhooks are optional on Node: an installation that is not externally
reachable relies on polling, and Node tests deliver webhooks from a local
fixture sender. The Worker from slice 0 receives real deliveries for the
acceptance run.

### 7. GitHub widgets and end-to-end scenario

Add pull-request, issue, repository and workflow-run widgets on the normalized
records. Hostile provider fixtures with HTML, SVG, event handlers, Markdown
and unsafe URL schemes execute in neither administrative nor display views.
The complete scenario, from App registration and authorization through a
workflow change to the display, passes on Node/SQLite and Workers/D1. PR CI
runs it against a recorded GitHub fixture server; a live run against GitHub on
the slice 0 Worker is the acceptance evidence, run manually or tag gated.

### 8. Go clients and conformance harness (parallel track)

Generate official Go display and collector clients from the canonical public
contract, as [SDK architecture](SDK_ARCHITECTURE.md) schedules for Phase 2,
and publish the language-neutral extension conformance harness. Go must pass
the same cross-runtime protocol and streaming fixtures as TypeScript and
Python. This depends only on the public contract, so it runs alongside slices
4 to 7. Dart and Swift stay experimental under
[ADR 0017](decisions/0017-client-sdk-languages.md).

## Order and dependencies

```text
0 Worker env ─────────────────────────────┐
1 SDK + checkpoints ─┬─ 2 jobs ──┐        │
                     └─ 3 broker ┴─ 4 App ─ 5 polling ─ 6 webhooks ─ 7 widgets
8 Go clients + harness (after 1, parallel with 4–7)
```

Why this order:

- **Contracts before GitHub.** Slice 1 settles the checkpoint and generation
  contract that polling, webhooks and widgets all commit through. Building
  GitHub first would encode its shape into the SDK.
- **Broker before the App.** The App is the first code that holds a real
  provider credential and makes real outbound calls. Doing slice 3 first means
  no token ever travels outside the broker, even in a prototype.
- **Polling before webhooks.** The architecture makes reconciliation the source
  of correctness. Webhooks then only shorten latency, and their ordering tests
  have a polling job to race against.
- **G24 rides with its first callback.** The owner moved it to Phase 2 because
  no OAuth flow existed; slice 4 introduces the first one.
- **The Worker comes first** because real webhook delivery and the live
  scenario need it, and the G1 evidence's second tier can reuse it at once.
- **Go is independent** of the provider work, so it should not wait on it.

## Repositories

All slices land in `seriously`. Phase 2 needs nothing from `seriously-cloud`:
self-hosted installations own their GitHub App, and the hosted, centrally
operated App belongs to Phase 5. `seriously-client` may add viewers for the new
record kinds through its SDK, but no gate depends on it. Any change that does
span repositories gets linked, coordinated PRs, per the project's PR process.

## CI cost

- The checkpoint contract kit, broker, webhook and callback suites are unit and
  adapter tests; add them to the existing `vitest` shards rather than new jobs.
- Go gets one path-filtered job that runs only when the contract, generators or
  Go sources change.
- The live GitHub scenario never runs on ordinary PRs; PR CI uses the recorded
  fixture server so the browser shards do not gain a network dependency.
- The new end-to-end journey must stay off the current critical path
  (`auth-worker.spec.ts`); give it its own file so Playwright can shard it.

## Exit-gate checks

Each row is one clause of the roadmap's Phase 2 gate, split where a clause
names more than one property. "Both" means Node/SQLite and Workers/D1.

| ID | Check | Slice |
|---|---|---|
| P2-01 | Atomic record, cursor and event checkpoints, with failure injected between operations, on SQLite and D1 | 1 |
| P2-02 | Idempotent upserts and disconnects leave no partial checkpoint | 1 |
| P2-03 | Bounded backoff, terminal failures, maximum attempts and dead-lettering | 2 |
| P2-04 | Two workers racing across lease expiry; stale fencing tokens cannot commit | 2 |
| P2-05 | Maintenance triggers reject missing, invalid, revoked, expired and wrongly scoped credentials without claiming work, for systemd/cron and Worker shapes, and are rate bounded | 2 |
| P2-06 | Indeterminate external actions reconcile or need an audited decision, never an unprotected automatic retry (fixture provider) | 2 |
| P2-07 | Broker rejects private, loopback, link-local, metadata, rebound and redirect-switched destinations without an approved capability | 3 |
| P2-08 | Slow streams, excess redirects, encoded or decoded overruns and compression bombs terminate within bounds on both, with no partial checkpoint | 3 |
| P2-09 | Callback state: expired, replayed, session-, installation-, tenant- and configuration-mismatched state rejected on both | 4 |
| P2-10 | **G24 (from Phase 1):** database and backup canaries prove raw callback-state values are never stored | 4 |
| P2-11 | CI rejects any GitHub App permission outside the read-only allowlist | 4 |
| P2-12 | Token revocation turns synchronization terminal | 4 |
| P2-13 | Canary private key and token absent from every HTML, loader, action, JSON, error, log, event, diagnostics, telemetry and export path | 4 |
| P2-14 | Multi-page fixtures for every GitHub record kind, including deletion from a later page | 5 |
| P2-15 | With webhooks suppressed, scheduled polling discovers updates and deletions | 5 |
| P2-16 | Valid signatures over exact raw bytes enqueue once; duplicates enqueue once; missing, malformed and mismatched signatures enqueue nothing | 6 |
| P2-17 | Oversized and slow bodies terminate under byte, time and rate limits without enqueueing | 6 |
| P2-18 | Polling and webhook jobs from the same provider state cannot commit out of generation order on SQLite or D1 | 6 |
| P2-19 | Hostile HTML, SVG, event-handler, Markdown and URL-scheme fixtures execute in neither administrative nor display views | 7 |
| P2-20 | Authorization through workflow change to display passes on both | 7 |
| P2-21 | Go display and collector clients pass the shared protocol and streaming fixtures; the published harness passes the reference provider | 8 |
| P2-22 | Every new session-authenticated route is in the authorization and CSRF matrices | all |

P2-21 is not in the roadmap's gate text today, although the roadmap lists Go
clients and the harness as Phase 2 deliverables. This plan adds it to the gate
so the deliverable has a check.

Track progress in a `docs/phase-2-exit-gate-audit.md` in `seriously` using the
same covered, partial, missing and deferred states as the Phase 1 audit, and
open it with slice 1 so each slice updates its own rows.

## Decisions taken in this plan

The owner asked for reasonable calls with the reasoning recorded; each can be
reversed by editing this section.

1. **Per-installation GitHub App via the manifest flow** (ADR 0023), rather
   than a shared Seriously App or keeping personal access tokens.
2. **No externally mutating GitHub actions in Phase 2.** The indeterminate
   outcome machinery is proven with a fixture provider.
3. **Webhooks are optional on Node**, mandatory in the Worker acceptance run.
4. **The demo `gh` path is removed in slice 5**, once App polling replaces it.
5. **Go clients are a gate check (P2-21)** and run in parallel.
6. **Slice 0 owns the persistent acceptance Worker**; G1 tier 2 reuses it.
