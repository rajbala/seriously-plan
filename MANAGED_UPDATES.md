# Next phase: managed server updates

## Goal and sequencing

Immediately after the current portable-installation/onboarding slice, deliver
**Check for updates** and **Update now** for the single-installation Seriously
server. This is the next tightly scoped phase, before resuming Phase 2 of the
numbered roadmap. Call it **Phase 1.5 — managed updates**; do not renumber the
existing phases or bring hosted tenancy/billing into this milestone.

The first cloud product surface is a minimal release catalog in
`seriously-cloud`, using **React Router Framework Mode**, TypeScript, and the
Cloudflare Workers deployment adapter. Extend the existing health/readiness and
public-package scaffold; preserve its conformance and repository-boundary tests.
It currently uses a plain Worker entry point, so Framework Mode adoption is an
explicit deliverable, not an assumption about existing implementation.

## User experience

An owner opens Settings → Updates and sees the installed version, supported
installation method, last successful check, latest compatible stable version,
release notes, and any reason installation is unavailable.

- **Check for updates** fetches fresh release metadata. A failed check reports
  that status without presenting stale metadata as a successful current check.
- An optional, enabled-by-default daily check uses jitter, conditional requests,
  bounded timeouts, and backoff. Owners can disable scheduled checks. It never
  downloads or installs an update automatically.
- **Update now** requires an authenticated installation owner and an explicit
  confirmation of the exact target version and expected interruption. The action
  creates a durable operation whose progress survives the Hub restarting.
- Progress identifies preparation, backup, download verification, stopping,
  migration, activation, readiness verification, and success or recovery required.
  Reconnection shows the same operation rather than submitting another update.
- An unsupported or externally managed deployment still supports checking, but
  shows precise update instructions and a reason instead of a nonfunctional
  Update now button. No cloud account is required solely to operate the Hub.

This phase updates the Hub/server only. Client/display/collector updates,
prerelease channels, unattended installation, staged fleet rollout, tenancy,
billing, general remote commands, and a full cloud administration console are
out of scope. Local TLS onboarding and renewal remain separate installation work.

## Minimal central service

The release catalog is small enough to ship without a tenant database or a new
release-management UI. Reviewed CI publishes immutable, signed release manifests
and promotes one stable-channel pointer. React Router resource routes expose a
versioned manifest API; a simple release page uses a route loader. Existing
health/readiness routes remain available. Publisher credentials and download
broker logic stay server-only and must not enter browser bundles or source maps.

Each manifest identifies its format version, monotonically increasing catalog
sequence, publication/expiry times, server version, release notes, supported
upgrade-from versions, protocol/schema compatibility, and required updater
version. Artifact entries identify installation format, OS/architecture,
immutable asset identity, byte size, cryptographic digest, signature/provenance,
and a compatible migration/recovery recipe identifier. A recipe selects reviewed
local updater behavior; it is not a shell command or script supplied by the API.

The catalog knows what the latest release is and where its artifacts live. It
never receives installation credentials, dashboards, provider secrets, recovery
keys, or backups, and never pushes an execution command to an installation.
Checks send the version, build identity (commit/tree), platform and format
needed for compatibility and for recognizing the installed build.
No persistent installation identifier or telemetry registration is *required*: a
Hub that omits one receives an identical decision, manifest and status. The
catalog does record the installations that choose to identify themselves, and
counts anonymous checks in a bounded daily aggregate, per
[ADR 0016](decisions/0016-update-protocol-and-check-in-records.md).
Application logs redact credentials and temporary download grants.

Until source publication, artifacts remain in **private GitHub Releases** as
already approved. The first delivery path uses a narrowly scoped, revocable
operator-issued release-download credential, stored server-side, with no GitHub
repository token exposed to clients. The cloud broker authorizes download of an
exact approved asset and streams it or issues a short-lived asset-bound grant.
Its GitHub access is read-only and scoped to release distribution. Private
metadata and artifacts require authorization during this private stage; health
routes do not reveal them. Revoked/expired credentials fail closed with a useful
Updates status; they never disable an otherwise working Hub. Issuing credentials
uses a documented operator procedure, not hosted signup or billing.

The signed manifest uses immutable artifact identities rather than expiring URLs;
a fresh download grant may be obtained without changing the signed release.
Anonymous distribution after source publication is a separate policy change.

## Portable local update authority

`seriously` owns the public manifest contract, version checks, Updates UI,
operation journal, verification logic, and deployment-adapter contract. The
private catalog implements that public protocol; no private source dependency is
introduced. The catalog is a default distribution service, not a runtime license
check or an application-availability dependency. The protocol and trust-root
configuration support an explicitly configured compatible mirror.

Update execution belongs to a separately installed, narrowly scoped host updater,
not the Hub request handler. The updater authenticates local requests, permits
only the selected installation and verified release operations, and rejects
arbitrary paths, commands, mounts, images, and executable URLs. The web server
must not gain a host Docker socket, unrestricted sudo, or general host execution.
The helper revalidates target identity and authorization when accepting an
operation; Hub API actions require owner authorization, CSRF protection, and
idempotency keys. A durable exclusive installation lock prevents concurrent
updates, migrations, restores, or conflicting maintenance operations.

Ship two execution adapters for the managed installation paths:

1. Native Linux/systemd: activate immutable versioned runtime directories using
   the service manager, preserving configuration and persistent data.
2. Managed OCI: a host-side updater replaces only the registered Seriously
   container with an image pinned by digest, preserving its declared data volume,
   configuration, network and certificate bindings. Document a bounded supported
   Compose topology; Docker/Compose is the first OCI implementation, not the
   platform-independent core contract or a Proxmox/LXC requirement.

A native installation inside an LXC or VM uses the same native adapter. Existing
external container orchestration, Kubernetes, arbitrary OCI engines, and
Workers/D1 get check/status plus manual or platform-managed instructions in this
phase. They must not claim one-click update support. Their full release-upgrade
matrix remains in Phase 6.

## Integrity, migration, and recovery

The updater embeds trusted release verification keys. HTTPS and catalog access
alone do not authorize new executable code. Verify manifest signatures, expiry,
sequence/replay rules, compatibility and artifact digests before activation;
reject unknown keys, tampering and unapproved downgrades. Document signed trust-key
rotation. Release building/signing permissions are separate from ordinary catalog
serving. Keep the last accepted sequence durably; an old valid manifest cannot
silently undo a newer release decision. A recovery restore is a distinct local
operator procedure, not a downgrade selected by the catalog.

Use one durable operation journal outside replaceable application files:

1. Validate the requested release, updater compatibility, available disk space,
   installation adapter, writable paths, and recovery prerequisites.
2. Stage and verify the immutable artifact. The live server continues running
   while downloading; network failure here leaves the installed version alone.
3. Enter maintenance, drain writes and jobs, and create and verify an
   application-consistent pre-upgrade backup. Abort before migration if backup or
   recovery-material verification fails. Retain the previous executable/image.
4. Stop the old application; apply only supported migrations under the update
   lock, activate the new runtime, and start it in maintenance mode.
5. Verify application readiness and the exact running release identity before
   reopening writes. Persist success and display the new version.

Crash/restart recovery resumes from recorded stages and verified artifact
identities; it must not duplicate migrations or mark an unverified release
successful. If migration/activation/readiness fails, preserve diagnostics and
keep writes closed. Before any new-version writes are admitted, the supported
recovery path restores the matching pre-upgrade domain backup and prior runtime,
using existing restore fencing/epoch rules. Authority and recovery stores are
preserved, never blindly rolled back. Older binaries must never open upgraded
data. After writes have reopened, rollback is an explicit operator recovery
operation with a data-loss warning, not an automatic response to a later crash.

Implement and test the supported recovery path in this phase; do not enable
Update now for an adapter whose safe recovery has only been documented. An
unrecoverable operation stays in maintenance and exposes local recovery
instructions; repeated startup or button presses must not erase evidence.

## Reviewable slices

1. Public release/update schemas, compatibility rules, trust model, and shared
   valid/hostile fixtures; define the managed native and Compose support matrix.
   **Partially delivered.** The wire contract, signed-envelope publication, the
   versioned check and manifest endpoints and recorded check-ins now exist in
   `seriously-cloud` (see its `docs/update-protocol.md`), written so the public
   half can adopt them unchanged. Still open, and still owned by `seriously` per
   [REPOSITORY_BOUNDARIES](REPOSITORY_BOUNDARIES.md): the public schema and
   fixture packages, the portable verification and compatibility gates, and the
   managed native and Compose support matrix. This slice does not close until
   those land.
2. React Router Framework Mode composition in `seriously-cloud`, private
   download authorization, CI publication of signed manifests, and a release
   page. No customer lifecycle routes. Framework Mode arrives with the rendered
   release page rather than ahead of it; the JSON resource API does not need it.
3. Owner-only Updates UI/API with installed build identity, explicit checking,
   scheduled check controls, stale/offline handling, and adapter capability display.
4. Narrow local updater and native/systemd execution with durable progress,
   verified backups, migrations, readiness and crash recovery; connect Update now.
5. Managed OCI execution using the same operation contract and recovery gates;
   installer registration, upgrade fixtures and user documentation.

Deliver each slice through reviewable PRs. Promote stacked drafts one at a time;
merge only fresh Codex-approved heads with green required CI. Avoid duplicate CI
runs for draft changes. These slices are the entire phase, not a new hosted
product roadmap.

## Exit gate

Using two genuine versioned releases and the running central service, an owner
can check, inspect release notes, and update both a managed native installation
and the documented managed OCI installation through the UI. Reconnecting after
restart shows the correct operation and exact installed version. Dashboards,
users, provider credentials, configured integrations, and supported protocol
clients still work. Every supported upgrade-from version in this initial
manifest has an executable migration/recovery fixture; unsupported versions are
explicitly refused with instructions.

Tests exercise unauthorized users, CSRF, duplicate requests, concurrent restore
or update, incompatible versions/platforms, catalog outage, expired/revoked
release credentials, stale/replayed or forged manifests, wrong hashes, expired
grants, insufficient disk, failed backup, interrupted downloads, crashes at each
durable stage, failed migrations, and failed readiness. A forged catalog cannot
execute arbitrary commands. Private release assets and server-only credentials
never appear in unauthenticated responses, browser bundles, logs, or public CI.

The service can be unavailable without breaking existing Hub operation; manual
checking accurately reports failure and scheduling backs off. Both adapters
recover from a failed upgrade with matching code/data while preserving external
authority. Unsupported deployments present working manual instructions. Publish
installation, update, signing-key rotation, and recovery procedures with these
tests; retain the broader Phase 6 matrix as a later launch gate.
