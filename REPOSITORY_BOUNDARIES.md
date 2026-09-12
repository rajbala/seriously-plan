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
- multiple users, dashboards, displays, and integrations;
- provider and widget SDKs;
- official providers and collectors;
- authentication, encryption, backup, restore, import, and export;
- SQLite and single-installation D1 adapters;
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
@seriously/web-ui
@seriously/provider-github
```

## Private repository: `seriously-cloud`

The private repository contains only hosted-service concerns:

- tenant resolution and membership;
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

## Licensing decision gate

Before accepting external contributions, choose and document either:

- Apache-2.0 for broad adoption and a simple private dependency relationship;
  or
- AGPL-3.0 plus a commercial license and an appropriate contributor agreement.

This is a legal and governance decision, not merely a build setting, and should
be reviewed by qualified counsel.
