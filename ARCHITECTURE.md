# Product and architecture

## Product model

Seriously is a dashboard for protected developer and infrastructure resources.
Users configure providers such as GitHub, Codex, Claude Code, GitLab, and AWS,
then assign views to browsers or dedicated kiosk displays.

The [north-star command-center scenario](PRODUCT_SCENARIO.md) is the product
acceptance reference: agent attention, CI and review status, usage, deployments,
host health, and recent activity compose from provider-neutral records.

The system has four concepts:

- **Hub**: configuration, authentication, normalized data, history, and UI.
- **Provider**: a server-side integration with a protected resource.
- **Bridge**: the optional outbound host daemon that enrolls a machine and runs
  collector and agent adapters for selected local activity. Remote control uses
  the same boundary later but is disabled in initial releases.
- **Display**: a read-only enrolled browser or kiosk assigned to dashboards.

```text
GitHub / GitLab / AWS ---- provider ----+
                                        |
Codex / Claude Code ---- bridge ------- Hub ---- browser
                                        |
                                        +-------- Cage display
```

Agent sources support two collection paths: individual native-plugin hooks and
[organization server-side API connections](ORGANIZATION_CONNECTIONS.md). The latter
and its audience policies are planned, not implemented. Collection authority,
member visibility and display assignment are separate boundaries.

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
private hosted product runs on Workers/D1. Its first user-facing cloud surface is
the [managed-update release catalog](MANAGED_UPDATES.md), composed with React
Router Framework Mode loaders and resource routes. It serves signed metadata and
authorized artifacts; a separate constrained local updater performs owner-requested
updates. Catalog availability never gates existing Hub operation.

## Portability boundary

Domain, UI, and provider code depend on injected capabilities:

```ts
interface PlatformServices {
  repositories: RepositoryFactory;
  transactions: TransactionRunner;
  secrets: SecretStore;
  jobs: JobScheduler;
  events: ChangeNotifier;
  crypto: CryptoProvider;
  clock: Clock;
}
```

They do not import SQLite drivers, D1 bindings, `node:fs`, child processes, or
Cloudflare-specific APIs. Deployment adapters may use those facilities.

Repositories are purpose-specific domain ports, not a generic SQL or query
escape hatch. SQLite and D1 adapters share a contract suite for transaction,
ordering, concurrency, pagination, and failure semantics. A new database adapter
must pass that suite without changes to domain or extension code.

The portable substrate is:

- a Web `Request`/`Response` runtime;
- outbound HTTPS;
- Web Crypto;
- persistent SQLite-compatible SQL;
- environment-provided secrets; and
- a mechanism that periodically invokes an authenticated maintenance handler.

Durable Objects, KV, R2, Queues, and Workflows are not architectural
dependencies. Durable Objects are the first hosted change-notification adapter,
not a source of truth or a requirement for the public deployment.

## Data and job model

Provider data is normalized into typed records and events. Provider plugins do
not own UI markup or receive unrestricted database access.

Scheduled work and webhook deliveries are durable SQL rows. Workers claim a
bounded number with expiring leases. Every claim receives a monotonically
increasing fencing token; commits from an expired or superseded claim are
rejected. Work is idempotent and resumable, and external actions use their own
idempotency keys where the provider supports them. Transient failures use
bounded exponential backoff with jitter and a maximum attempt count. Invalid
configuration, revoked credentials, and other permanent failures become
terminal immediately. Exhausted work moves to an inspectable dead-letter state
and cannot starve newly eligible jobs. The same job logic can be invoked by a
systemd timer, cron, or Cloudflare Cron Trigger.

Automatic retries of externally mutating actions require an enforceable
provider or Seriously idempotency mechanism. If a connection fails after an
unprotected action may have been accepted, the outcome becomes `indeterminate`:
the Hub reconciles it through a provider read when possible or requires an
audited user decision. It never blindly retries or falsely reports failure.

An external provider action is dispatched only from a durable action intent.
Creating or claiming that intent atomically rechecks the initiating session,
membership, tenant lifecycle, and action generation and is the authorization
linearization point ordered against revocation. If revocation wins, the claim
cannot dispatch; if the claim wins, revocation reports the already-committed
dispatch and cannot pretend it was cancelled. Dispatch results and idempotency
evidence are durably reconciled to that intent.

Every dashboard-affecting transaction appends a monotonically ordered change
event to a transactional outbox in the same commit as the state change. An
injected `ChangeNotifier` publishes only a scoped high-water notification; the
durable SQL log remains authoritative, so lost, duplicated, delayed, and
out-of-order notifications are harmless. Adapters expose typed `publish` and
abortable `subscribe(scope, cursor)` operations and pass one contract suite.

The first adapters are an immediate in-process notifier, an explicit
database-poll notifier, and a hosted Durable Object notifier partitioned by
organization or a documented organization shard. The Durable Object fans out
notifications and may use hibernating WebSockets internally, but holds no
irreplaceable state. PostgreSQL `LISTEN/NOTIFY`, Redis, or NATS adapters may be
added later without changing domain or browser protocols. Production selects a
notifier explicitly; adapter failure is observable and does not silently
downgrade to polling. Database polling is the portable default and uses bounded,
jittered idle intervals against the indexed outbox sequence.

SSE remains the browser-facing protocol and clients reconnect with
`Last-Event-ID`. A persistent Node server can wake listeners immediately; a
stateless runtime uses its selected notifier while the SSE response remains
open. On notification, timeout, and reconnect, the server reads authoritative
events after the cursor. Correctness never depends on notification delivery.
The stream reports the oldest retained event cursor. A
missing, malformed, or older cursor causes an explicit full-snapshot
reconciliation before incremental delivery resumes. Cursors are bound to the
dashboard assignment and event-log generation; wrong-scope cursors and values
beyond the current high-water mark are invalid and also force reconciliation.
Active streams revalidate the display credential and dashboard assignment at
least every 60 seconds and before delivering data after an authorization-change
notification. Expiry, revocation, or reassignment closes the stream within that
maximum interval.

Cursor validation, retention-floor observation, and replay occur in one
consistent database view. If an adapter cannot hold that view, the response
verifies that its first returned sequence is contiguous with the requested
cursor and its observed floor; any gap or concurrent compaction forces a scoped
snapshot instead of returning a truncated replay.

Snapshot reconciliation has a transactional event boundary. The server reads a
dashboard snapshot and its event high-water mark from one consistent database
view, returns both, and replays events strictly after that mark. If an adapter
cannot provide that transaction shape, it captures the high-water mark first
and replays everything after it, allowing idempotent overlap but never a gap.

## Provider model

The provider SDK exposes metadata, configuration and credential schemas,
health, synchronization, and optional actions. Providers receive scoped HTTP,
secret, synchronization-checkpoint, and logging capabilities. A checkpoint
atomically commits idempotent record upserts, deletions, the next cursor, and
the resulting change event. Providers cannot advance a cursor separately from
the records it describes. Each provider configuration also owns a monotonic
synchronization generation. Checkpoint commit uses compare-and-swap against that
generation, so distinct polling and webhook jobs cannot commit stale snapshots
or move a cursor backward; adapters may instead serialize one synchronization
per configuration while preserving the same contract.

Supported provider forms:

1. Bundled, reviewed TypeScript providers that run on Node and Workers.
2. Remote HTTPS collectors/providers using a versioned protocol.
3. Optional local subprocess providers for Node only, never the universal
   plugin contract.

GitHub is the first remote provider. Codex and Claude Code begin as collectors
because their useful state typically originates on developer workstations.
Collectors do not upload prompts, source, terminal output, or conversation
content by default. Each collector supplies a collector-scoped idempotency key
and monotonically increasing sequence. Duplicate submissions are harmless and
older out-of-order status updates cannot replace newer state.

The GitHub provider follows every pagination cursor for repositories, pull
requests, issues, and workflow runs. Scheduled reconciliation remains the source
of correctness when webhooks are delayed or lost and detects both updates and
deletions. Webhook ingress authenticates the exact raw request bytes before
parsing or enqueueing; missing, malformed, or body-mismatched signatures fail
closed. Raw streams are consumed under configured byte and read-time limits,
plus unauthenticated source and global rate limits, before memory is committed;
oversized or slow bodies are terminated without enqueueing. GitHub authorization
state is high entropy, expiring, single-use, and bound to the initiating user
session, Seriously installation or tenant, and provider configuration. The
GitHub App manifest is versioned and CI compares it with an explicit read-only
permission allowlist, rejecting any additional write or administrative scope.
All provider HTTP responses are streamed through the scoped broker under strict
connect, first-byte, idle-read, and total deadlines; encoded and decoded byte
ceilings; bounded redirects; and decompression-ratio limits. Slow, oversized,
and compression-bomb responses terminate before exhausting a Worker or Node
process and never produce a partial synchronization commit.

## Authentication and secrets

Identity classes remain separate:

- users administer an installation;
- displays can only read assigned dashboards;
- collectors can only submit allowed record kinds;
- providers have narrowly scoped external credentials.

The standalone installation uses capability-based `owner`, `admin`, `member`,
and `viewer` roles. Owner can manage users, role ownership, backup/restore, and
installation settings; owner and admin can manage provider secrets,
integrations, collectors, displays, and dashboards; member can operate existing
integrations and edit dashboards; viewer is read-only. Every privileged route
checks a named capability, and an actor cannot grant a capability it lacks.
Installation invitations are short-lived, identity-bound, atomically single-use,
and audited. Owner-count validation and mutation share a serialized transaction;
the final owner cannot leave, be removed, or demote itself without an atomic
ownership transfer.

Standalone password authentication stores only unique salts and versioned
Argon2id verifiers produced by an audited cross-runtime implementation whose
memory and time parameters meet a documented minimum and are periodically
recalibrated. Passwords are never encrypted, logged, exported, or retained after
verification. Optional WebAuthn credentials store public keys, never private key
material. Each ceremony uses an expiring, cryptographically random, single-use
server challenge bound to the session and intended operation. Assertion
verification requires the expected RP ID, exact allowed origin, ceremony type,
user presence, configured user verification, credential ownership, signature,
and monotonic counter semantics; counter regressions follow an explicit
cloned-authenticator policy rather than being ignored.

Login verification is bounded by account, network source, and deployment-wide
rate controls with increasing delays and generic responses. Limits cap expensive
Argon2id concurrency but recover automatically and never create a permanent
attacker-triggered account lockout. A successful login rotates the session ID.
Administrative sessions use host-only `Secure`, `HttpOnly`, appropriately
`SameSite` cookies; credentials never enter URLs or Web Storage. Plain HTTP is
permitted only by an explicit loopback development mode that cannot be enabled
in production. The server caps administrative sessions at 24 hours absolute and
30 minutes idle; deployments may shorten but not extend those limits. Activity
cannot extend the absolute deadline. Sensitive operations require authentication
within the preceding five minutes, renewal rotates the session identifier, and
clock-driven expiry behaves identically on Node and Workers.

Session, display, collector, invitation, callback-state, and other bearer
capabilities are high-entropy values disclosed once. Storage contains only a
keyed or cryptographic verifier plus a non-secret lookup prefix, scope, expiry,
authentication epoch, and revocation metadata—never the bearer value. Database
and backup scans use canaries to enforce this for every credential class. A
restore advances the installation or tenant authentication epoch and rotates all
restored sessions and machine credentials, so credentials revoked after an old
backup cannot become valid again. A credential generation held outside restored
data also invalidates restored password and WebAuthn credentials. Recovery then
requires a deployment-bound out-of-band recovery capability held outside the
replaced database. Node installations use a permission-restricted local recovery
secret or physical console path; Workers installations require a separately
configured deployment secret. A challenge-response proof authorizes exactly one
owner reset, rotates the capability, and is rate limited and audited. It is not
accepted as an ordinary remote login. No restored verifier or authenticator can
mint a current-generation session before that reset.

User and membership authorization has a monotonic generation captured by each
privileged mutation. Removal, demotion, or role change advances it in the same
transaction, and every mutation rechecks it at commit. Work authorized under an
older generation cannot commit after access changes.

Each administrative session also has its own monotonic generation captured by
privileged work and rechecked at commit independently of the user's membership
generation. Revoking or rotating one session advances that session generation,
so an in-flight mutation authorized by the old session cannot commit even when
the user and role remain otherwise valid.

Privileged streaming responses capture the same generation and recheck it before
headers, before every emitted chunk, and at least every five seconds while
backpressured or generating data. Revocation closes exports, diagnostics, and
other long reads within five seconds and prevents any later chunk from being
published.

Provider secrets are encrypted before storage using a master key supplied by
the deployment. This includes OAuth client secrets and refresh tokens, API keys,
private keys, webhook secrets, and other provider credentials. Displays never
receive provider credentials. Display enrollment uses a short-lived code
approved from an authenticated administrative browser. Redemption atomically
consumes the code exactly once; concurrent redemption, reuse, expiry, and failed
approval do not issue credentials.

The display first creates a separate high-entropy device secret and sends only
its verifier with the enrollment request. Administrative approval binds the
human-readable code to that verifier; redemption requires proof of the device
secret, so the code alone is useless.

Secrets use envelope encryption. Each installation, or each organization in the
hosted edition, has a random data-encryption key (DEK). Secrets are encrypted
with AES-256-GCM using a fresh cryptographically random nonce for every write;
nonce reuse under a DEK is forbidden. Authenticated context binds the ciphertext
to its installation or tenant, provider, credential name, and schema version so
ciphertext cannot be transplanted into another scope. Stored rows contain only
ciphertext, nonce, algorithm and DEK version metadata.

The DEK is wrapped with AES Key Wrap by a deployment key-encryption key (KEK)
that never enters SQLite or D1. Self-hosters supply it through an environment
secret, mounted secret file, or external secret adapter; the hosted Worker
receives it as a Worker secret. Providers access plaintext only through a scoped
`SecretStore` operation and never receive the KEK, raw DEK, or database access.
Plaintext is never cached persistently or included in logs, errors, browser
data, SSE, exports, telemetry, or source maps. Authentication failure, unknown
key versions, and context mismatch fail closed without returning partial data.

KEK versions permit rewrapping DEKs without rewriting every secret. DEK rotation
creates a new version and incrementally re-encrypts credentials, retaining an
old key only until migration is verified. Rotation first advances a key
generation and installs a write barrier: every write of any tenant-encrypted row
compares that generation at commit and retries encryption under the active DEK
if cutover has begun. Verification covers credentials, dashboards, normalized
records, events, jobs, exports, and every other encrypted row committed through
the barrier before an old key can be retired. Backup recovery treats key material
separately: a database backup requires a separately protected recovery package
or an externally retained KEK. A portable recovery package encrypts key material
under a user-held recovery key; a passphrase option derives that key with a
versioned Argon2id KDF using 64–1024 MiB memory, 3–20 iterations, parallelism
between 1 and 16, and a deployment-calibrated target of at least 500 ms on
supported recovery hardware. A bounded schema validates the algorithm, salt,
and all cost parameters before allocation or derivation. Values below or above
policy are rejected and newer packages may raise the versioned floor. Restore tests
decrypt a canary only after that material is deliberately reintroduced; deletion
purges wrapped DEKs and all recoverable copies according to retention policy.

Restore is a maintenance-barrier operation with a monotonically increasing
restore generation held outside the replaced data. New mutations and job claims
pause during replacement, and every in-flight mutation and job commit rechecks
the generation. Work authorized against the pre-restore generation cannot write
into restored state. Every response captures the generation and rechecks it
before headers and each streamed chunk. Restore closes new readers and drains or
terminates existing readers before replacement, so loaders, display SSE, exports,
and diagnostics cannot publish across the boundary.

Restore marks every pending or leased externally mutating job as quarantined.
It becomes eligible only when a provider-supported idempotency key proves replay
safe or reconciliation against evidence held outside the restored snapshot
establishes the outcome. Otherwise it remains `indeterminate` for an audited
human decision; restore never blindly redispatches it.
The dispatch claim also compares the external restore generation. Restore first
closes claims and drains all dispatch-capable work to a durable pre-dispatch or
post-dispatch state before replacement; it cannot replace the database while a
provider request is between linearization and recorded outcome.

Backups use adapter-provided point-in-time snapshots. SQLite uses its online
backup/snapshot facility rather than copying database files; D1 uses its
consistent backup/export primitive. The artifact represents one committed
database boundary, including encryption metadata and required event/job state.
A crash leaves either the prior complete artifact or the new complete artifact,
never a partially published backup. Each artifact has a canonical manifest that
covers every database byte and recovery-relevant metadata byte and is
authenticated by a key derived from or stored with the separately held recovery
key. Restore verifies it before replacing state and rejects truncation,
substitution, cross-installation use, and logically valid row tampering. The
complete standalone artifact—not only secrets or its manifest—is encrypted with
an authenticated streaming encryption format under separately held recovery
material before it can leave the host. Raw backup storage reveals neither user
records, password verifiers, dashboards, normalized records, nor event history.

A new installation cannot be claimed merely by reaching its public endpoint.
The installer generates a high-entropy, single-use bootstrap capability and
delivers it separately from the application URL (or provisions the first
administrator locally). Claiming the first administrator and consuming that
capability are one transaction. Once claimed, bootstrap endpoints remain
disabled; competing and replayed claims fail without revealing account state.

## Hosted tenancy

The public Hub models one installation. In the hosted product, an organization
is the tenant and ownership boundary. A person has one global hosted identity
and may belong to multiple organizations through explicit memberships. An
organization owns its dashboards, integrations, provider credentials,
collectors, displays, jobs, events, audit history, subscription, and quotas.

Membership roles begin with `owner`, `admin`, `member`, and `viewer`. Permission
checks use named capabilities rather than scattered role comparisons so roles
can evolve without rewriting route logic. Invitations are single-use,
short-lived, bound to an organization and intended identity, and recorded in
the audit log. The last owner cannot leave or be removed; ownership must first
be transferred or the organization must enter its deletion lifecycle.

The initial role-to-capability policy is explicit:

| Capability | Owner | Admin | Member | Viewer |
|---|:---:|:---:|:---:|:---:|
| View dashboards | yes | yes | yes | yes |
| Edit dashboards and widgets | yes | yes | yes | no |
| Operate existing integrations | yes | yes | yes | no |
| View or change integration settings and credentials | yes | yes | no | no |
| Enroll or revoke displays and collectors | yes | yes | no | no |
| Invite, remove, or change members below owner | yes | yes | no | no |
| Grant or revoke owner; transfer ownership | yes | no | no | no |
| Manage billing, exports, deletion, and organization settings | yes | no | no | no |

Every route authorizes a named capability. Role assignment cannot grant a
capability that the acting identity does not possess. Owner-count validation
and membership mutation occur in one serialized transaction so concurrent
leave, removal, demotion, and ownership-transfer requests cannot produce an
organization with zero owners.

The private hosted Worker resolves a global authenticated identity, verifies
membership in the selected organization, and constructs organization-scoped
repositories before entering shared domain and route code. Organization
selection supports users who belong to more than one organization, but URL,
hostname, cookie, header, and body hints never establish authorization.

Seriously Cloud owns the global hosted identity. It is passwordless: an
expiring, single-use verified-email link bootstraps the account, after which a
passkey is the primary authenticator. Users are prompted to register at least
two passkeys. Email-based recovery is delayed, notifies existing verified
channels, invalidates all sessions and prior recovery attempts, and requires a
new passkey before privileged access resumes. Every authenticator registered
before recovery is revoked or quarantined and cannot authenticate afterward;
the user may explicitly re-enroll a still-trusted device only from the recovered
session. Email links store only verifiers,
expire within 15 minutes, and are rate-limited by address, source, and service.
During the delay, any current passkey holder can sign a single-use cancellation
that advances the recovery generation, freezes email recovery, and preserves the
existing authenticators. A compromised inbox cannot override that signed veto;
resuming recovery requires the separately verified manual recovery process and
not merely another email link. Every initiation, veto, freeze, and completion is
notified through all configured independent channels and audited.
Hosted WebAuthn, session lifetime, revocation, CSRF, recent-authentication, and
recovery rules meet the same or stronger gates as standalone authentication.
Optional social login may be linked only as a convenience and is never the sole
recovery authority. Maintained WebAuthn and mail libraries implement these
protocols; Seriously does not hand-roll them.

Global identity tables use stable user keys and do not carry `tenant_id`.
Membership is the explicit join from a global user key to an organization key.
Tenant-owned D1 tables include `tenant_id` in primary keys, foreign keys,
uniqueness constraints, cache keys, jobs, and change events. Hosted request code
cannot obtain a raw D1 binding.

An organization lifecycle state and monotonic lifecycle generation are checked
at every request boundary and rechecked at every tenant-bound commit and before
publishing a long-running response, stream, or export. Leased jobs capture and
recheck the same generation. Suspension or deletion atomically advances it and
disables memberships and all
tenant-bound display, collector, provider, webhook, and session credentials;
in-flight work cannot commit after the transition. Recovery within the stated
retention window restores access only through an explicit audited operation.
After that window, a clock-driven purge irreversibly removes customer records,
encrypted credentials, per-tenant key material, exports, and recoverable backup
material. Only narrowly documented audit or legal-retention records may remain,
and they contain no recoverable customer secrets or dashboard content.

Hosted membership removals, role changes, suspension, recovery, and deletion
use an idempotent denial-first transition. The authority first records a pending
generation that request-time, commit-time, and stream-time checks treat as
denied; D1 applies the transition; then the authority finalizes it. D1 failure
therefore leaves access closed while reconciliation retries instead of leaving
old authorization effective. Hosted restore remains closed until it reconciles
every restored
membership and lifecycle generation with this non-rollback state; older rows
are disabled or corrected before authentication resumes.

Cross-tenant operations use a separate private interface, identity store, and
session boundary. Operations roles grant named, revocable capabilities such as
tenant lookup, support diagnostics, suspension, export authorization, or purge
authorization. Every action requires explicit tenant targeting, reason and
ticket metadata, step-up authentication for destructive operations, and an
immutable audit record. Customer sessions and operations identities without the
specific capability are rejected.

Step-up assertions expire within five minutes, are single-use, and bind the
operations identity, destructive capability, target tenant, request digest, and
audit reason. A prior, replayed, or differently targeted assertion authorizes
nothing.

Plans define tenant limits for stored bytes, active displays and collectors,
provider synchronizations, ingestion requests, queued/running jobs, and outbound
event delivery. Admission reserves capacity atomically with the accepted write
or job claim, so concurrent requests cannot oversubscribe a limit. Rejected work
does not consume capacity, and quota counters are reconciled from authoritative
tenant-owned records. Enforcement is tenant-local and cannot consume another
organization's allocation.

Operations audit storage is append-only at repository and database boundaries.
No support, purge, retention, or tenant repository exposes update or delete for
audit facts. Corrections append a linked superseding record. Every operations
action, including lookups, diagnostics, and export authorization, uses a
recoverable prepare/finalize protocol: the authority first
reserves a sequence for the operation digest; D1 then commits an audit intent but
does not apply the destructive transition; the authority finalizes its
authenticated receipt only for that persisted intent; and a final D1 transaction
verifies the receipt, applies any transition, and marks the intent complete.
Read-only results are not released until the receipt is finalized and persisted.
Retries are idempotent at every phase. Reserved sequences can be explicitly
aborted, while finalized receipts and pending intents are reconciled until the
final D1 transaction succeeds. Thus an authority failure cannot leave an applied
but unreceipted destructive operation, and a D1 failure produces an inspectable,
recoverable state rather than an unverifiable gap. The authority retains the
canonical audit record and transition envelope—not only its digest—until it is
included in a verified later disaster-recovery baseline. Restore replays any
finalized receipt and record absent from D1 before reopening operations. The
receipt binds tenant, sequence, operation digest, intent identifier, and prior
receipt; verification
rejects rewritten D1 rows, a recomputed chain, unexplained gaps, and rollback.

Hosted per-tenant key status is held by a key authority outside shared customer
D1 data and its backup lifecycle. Purge destroys tenant wrapping material and
appends a non-rollbackable tombstone there before customer rows are removed.
Every unwrap and restore consults that authority; no cached status bypass is
accepted. During an authority outage, encrypted tenant reads and writes fail
closed rather than weakening purge guarantees. A pre-purge shared-D1 snapshot
cannot restore a tombstoned key or make its ciphertext decryptable. Hosted
backup tests restore pre-purge snapshots after retention and prove denial.
Every purge-sensitive tenant row—including dashboards, normalized provider
records, events, jobs, and exports—is encrypted under destructible per-tenant
material, not merely provider-secret rows. Raw snapshot inspection after
tombstoning must recover no customer content.

## Optional public usage leaderboard

The hosted service publishes separate leaderboards for hosted verified usage
and opt-in self-hosted reported usage. Self-hosted totals are never described as
verified unless backed by a provider-issued cryptographic receipt or an
authoritative read-only usage API. Signed transport proves which registered
installation sent a report; an open-source operator can still alter its meter.

The public Hub includes an optional publisher in the managed client SDK.
Enabling it requires informed consent and a chosen public alias. The installation
generates an Ed25519 key pair, registers the public key through a challenge, and
signs canonical versioned reports containing a pseudonymous installation ID,
monotonic sequence, time bucket, and aggregate input, output, and cache tokens by
provider and model. Reports exclude prompts, transcripts, source, repository
names, user identities, credentials, session identifiers, and file paths.
Time buckets are canonical half-open intervals of UTC instants. A dashboard may
project them into its configured IANA time zone, but local clock labels never
define report identity; daylight-saving transitions therefore produce correct
23- or 25-hour local days without duplicated or missing instants.
The private signing key is stored through the envelope-encrypted `SecretStore`
and is never reused for Hub authentication.

Hosted ingestion verifies registration, signature, schema, sequence, period,
idempotency, revocation, body/time limits, and rate limits before accepting a
report. Corrections are signed cumulative replacements for an open time bucket.
Closing a period prevents score replacement but never prevents a privacy
deletion. Deleting an operator's report removes it from retained and public data
without reopening the bucket or permitting a corrected replacement. Public
views use minimum aggregation thresholds
and visibly distinguish reported, provider-verified, and hosted usage. Estimated
spend is calculated centrally from a versioned public price catalog and labeled
as estimated; negotiated discounts and unobservable spend are never guessed.

Leaderboard eligibility is separate from report acceptance. A reported entry
must bind to an abuse-controlled hosted account, and one account cannot create
unbounded ranked identities. Provider evidence is verified independently and
bound to the same bucket. Anomaly detection can quarantine a score for review
but cannot silently rewrite it. No self-reported score competes in a verified
ranking.

Operators can preview the exact payload, disable reporting immediately, rotate
or revoke the reporting identity, delete the alias and retained reports, and
export their history. The signing key grants only report submission for its
registered installation and is never a Hub administration credential.

Report and alias deletion writes a non-rollbackable tombstone to the external
authority before removing D1 rows. Hosted restore and leaderboard reads apply
those tombstones, so a pre-deletion snapshot cannot republish deleted data.
Leaderboard reads fail closed whenever a fresh authoritative tombstone result is
unavailable; an outage cannot be interpreted as “not deleted.”

## Hosted pricing and billing

Seriously Cloud launches at **USD $5 per billable seat-month**. Seat quantity is
the number of concurrently active human organization memberships at each instant;
the invoice is the time-prorated integral of that quantity over the monthly
period. Replacing one member with another at the same instant keeps quantity
unchanged and does not charge two seats. Pending invitations, suspended or
removed memberships, displays,
collectors, service credentials, and provider integrations are not seats. The
same global identity in two independently billed organizations is one seat in
each organization. The open self-hosted product has no license or per-seat fee.

Stripe is the private hosted edition's first billing adapter. Stripe Checkout
collects payment details and Stripe Customer Portal manages payment methods and
cancellation; Seriously never handles raw card data. Signed Stripe webhooks are
read through a bounded streaming ingress with byte, total-time, idle-read,
concurrency, and pre-authentication source/deployment rate limits, then verified
over the exact raw bytes, stored idempotently, and reconciled by scheduled jobs.
Browser redirects and client claims never activate entitlements. Seriously
stores its own auditable subscription, price-version, seat-count, invoice, and
entitlement state keyed to opaque Stripe identifiers, so domain authorization
does not call Stripe synchronously. Seat changes update subscription quantity
with Stripe's monthly proration behavior and reconciliation repairs missed or
reordered webhooks.

Payment failure enters a documented grace period and then suspends hosted access;
it never immediately deletes customer data. Only the separate retention and
purge lifecycle can erase an organization. Billing code, Stripe secrets, webhook
handlers, product identifiers, tax configuration, and hosted pricing remain in
`seriously-cloud`; the public package exposes only vendor-neutral entitlement
and quota concepts where shared domain behavior needs them.

The hosted edition starts with one shared D1 database and may later use a fixed
set of D1 shards. Database-per-customer and platform-specific coordination are
not required for the initial service.

## Deployment shapes

All deployment shapes expose the same language-neutral public protocol. Actual
dashboard clients use the trust-scoped display SDK described in
[Client SDK architecture](SDK_ARCHITECTURE.md); the TypeScript implementation is
not the wire contract, and Python, Go, and Rust clients share its conformance
suite.

The [remote-control-ready architecture](REMOTE_CONTROL.md) extends the collector
into an outbound bridge while preserving these transports and trust boundaries.
Remote command execution is deliberately deferred; no early component exposes a
generic shell or relies on terminal scraping.

```text
Self-hosted VM/LXC:  React Router Node server + SQLite
Self-hosted edge:    React Router Worker + D1, one installation
Hosted service:      private React Router Worker + tenant-scoped D1
Lenovo appliance:    Cage/Chromium display enrolled with either Hub
```
