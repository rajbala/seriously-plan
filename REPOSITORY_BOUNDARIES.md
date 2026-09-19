# Public/private repository boundary

## Dependency rule

The boundary is enforced by separate repositories and build identities.

```text
seriously-cloud --depends on--> released @seriously/* packages
seriously       --depends on--> no private package or repository
```

Do not implement editions as branches, environment-variable dead code, or a
monorepo containing both source trees.

## Public repository: `seriously`

The public repository contains:

- complete single-installation Hub and responsive web UI;
- multiple installation users with invitations, capability-based authorization,
  removal and session revocation, plus dashboards, displays, and integrations;
- provider and widget SDKs;
- monorepo-managed display, collector, remote-extension, and administration
  client SDKs generated from or sharing canonical versioned wire schemas;
- the open outbound bridge, machine-identity and rendezvous contracts, agent
  adapters, and reserved durable command protocol;
- official providers and collectors;
- authentication, encryption, backup, restore, import, and export;
- SQLite and single-installation D1 adapters;
- public release-manifest and update contracts, update UI, verification and
  narrowly scoped local deployment updaters;
- container and Workers deployment instructions; and
- all tests required to validate self-hosting.

Suggested packages:

```text
@seriously/domain
@seriously/platform-contract
@seriously/database-contract
@seriously/db-sqlite
@seriously/db-d1
@seriously/hub-services
@seriously/provider-sdk
@seriously/widget-sdk
@seriously/client-display
@seriously/client-collector
@seriously/client-bridge
@seriously/client-remote-extension
@seriously/client-admin
@seriously/web-ui
@seriously/provider-github
```

## Private repository: `seriously-cloud`

The private repository contains hosted-service and release-distribution concerns:

- the initial React Router Framework Mode release catalog and private artifact
  download authorization, implementing public update contracts;
- organization creation, membership, invitations, roles, and ownership
  lifecycle;
- authenticated organization selection and tenant resolution;
- tenant-scoped D1 repositories and migrations;
- subscription billing and quotas;
- provisioning and suspension;
- managed domains, email, backups, and upgrades;
- abuse prevention and operational telemetry; and
- a separately authenticated support/operations console.

The hosted build pins exact public package versions. Production never depends
on a mutable branch or `latest` tag.

## Composition

The public application creates a complete Hub with single-installation
adapters. The private Worker creates the same Hub services with authenticated,
tenant-scoped adapters and adds private route manifests.

Public interfaces may expose general extension capabilities such as billing
status or installation management. They must not name private vendors or carry
private implementations.

React Router client and server dependency rules are enforced. Sensitive private
logic is server-only. Any JavaScript delivered to a browser is treated as
inspectable, regardless of minification.

## Leakage prevention

Public CI has no credential capable of reading `seriously-cloud`. Private CI may
read released public packages. The two repositories do not share publishing or
deployment tokens.

Every public release performs:

1. prohibited-name and secret scanning;
2. server/client dependency-boundary checks;
3. clean builds from only the public checkout;
4. inspection of client bundles and source maps;
5. SBOM generation; and
6. container-content inspection.

Private CI additionally builds an inventory of private server-only modules and
verifies that none appears in any delivered JavaScript artifact or source map,
including relative imports and embedded `sourcesContent`. Production browser
source maps are not published unless they pass that inspection and their
publication is intentional.

Envelope encryption is public infrastructure, not a hosted-only feature. The
public repository owns the portable `SecretStore` contract, authenticated
encryption format, wrapping and rotation workflows, recovery-package format,
and leakage tests. The private repository supplies only the hosted KEK source,
per-organization key lifecycle, audit integration, and operational policy.

## Tenant isolation requirements

Hosted repositories capture `tenantId` during construction. Routes and provider
code do not accept arbitrary tenant identifiers. Tenant-owned records use
composite tenant-aware primary and foreign keys.

All hosted repository contract tests create at least two tenants with identical
resource IDs and prove that reads, updates, deletes, events, webhooks, jobs,
exports, and caches cannot cross the boundary.

Repository scoping is necessary but not sufficient. Request-level adversarial
tests prove that hostname, slug, route, query, header, and body inputs cannot
select a tenant without an authenticated membership or tenant-bound machine
credential. These tests cover user routes, display snapshot and SSE routes,
collector ingestion, provider callbacks, and webhook ingress. They also verify
that conflicting tenant hints fail closed rather than selecting either tenant.

Hosted identity and organization records are deliberately separate: one user
may hold different roles in multiple organizations. Tests cover organization
creation, duplicate and expired invitations, invitation identity binding,
organization switching, cross-organization role differences, removal and
revocation, last-owner protection, ownership transfer, and deletion. Removing a
membership invalidates its active sessions and access without affecting the
same user's memberships in other organizations.

Global identity tables are exempt from tenant-key requirements. Memberships
join stable global user IDs to organization IDs; every other tenant-owned table
uses tenant-aware keys and constraints. Contract tests prove that this model
preserves one identity across organizations without weakening tenant isolation.

The private operations interface never reuses customer authentication or raw
tenant repositories. Its repositories require an explicitly authorized target
tenant plus an operations capability and audit context. Boundary tests reject
customer sessions, revoked operations identities, missing or mismatched tenant
targets, and every capability escalation.

## Licensing policy

The owner selected Apache-2.0 for `seriously`, the complete single-installation
product. It is the only repository intended for eventual open-source publication.
Its source, workspace metadata, packaged license files, and contribution policy
must consistently identify Apache-2.0.

`seriously-cloud` and `seriously-plan` remain private; the public product's license
does not apply to either repository's original source. Public dependency packages
retain their own licenses when consumed by the hosted product.

Repository visibility and protected package publishing are separate operations.
Selecting the source license does not publish packages, change repository
visibility, or waive the release, provenance, compatibility, and review gates.

The [managed-update phase](MANAGED_UPDATES.md) starts the cloud product surface
with release distribution only. Consuming verified release metadata and published
artifacts is not a private-source build dependency. The self-hosted Hub remains
operable without the catalog; credentials used for private release downloads grant
no remote-control or tenant access.
