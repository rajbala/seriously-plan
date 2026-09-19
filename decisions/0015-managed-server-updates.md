# ADR 0015: managed server updates and a minimal cloud release catalog

## Status

Accepted direction from the owner; implementation proceeds through reviewed PRs.

## Context

Portable installation needs an equally usable upgrade path. The roadmap required
release-upgrade and recovery tests but did not specify Check for updates or Update
now. The owner requested these in the very next tightly scoped phase and a minimal
central version/download service in seriously-cloud using React Router Framework
Mode. The cloud repository already has a plain Worker foundation to extend.

## Decision

Insert [Phase 1.5 — managed updates](../MANAGED_UPDATES.md) after the current
installation/onboarding work and before resuming Phase 2. Seriously owns the public
update protocol, owner UI, verification, operation journal and local updater.
Seriously-cloud owns the React Router Framework Mode catalog, release page and
private download authorization. Start with one stable channel and managed native
Linux/systemd and documented OCI adapters. Other installations get check/status
and manual instructions. Updates are explicit owner actions, never unattended.

The central service distributes signed metadata and artifacts, not remote commands.
Installed servers remain useful offline or during catalog outages. Private GitHub
Releases remain the artifact source until the separately authorized source release.
Verification keys and immutable artifacts, rather than the catalog's word alone,
authorize code installation. The local update authority is narrowly scoped and
separate from the web process. Updates require verified backups, exclusive
maintenance, compatible migrations, readiness and tested recovery.

## Alternatives

- Only document manual upgrades: does not meet the requested user experience.
- Put host-management privileges in the Hub: unnecessarily exposes host authority
  through the application request process.
- Build cloud identity, tenancy and billing first: broadens the next phase without
  being necessary to serve releases.
- Couple updating to Proxmox or LXC: excludes supported conventional installations.

## Consequences

This adds a minimal cloud product surface without importing private implementation
into the public build. Runtime availability and release-distribution availability
remain separate. The managed adapters have explicit support limits and must pass
failure/recovery gates before Update now is enabled. Client updates, unattended
updates, fleet rollout and the full hosted product remain later work. The broader
Phase 6 Node/SQLite and Workers/D1 release-upgrade matrix is retained.
