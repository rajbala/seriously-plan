# Architecture decision records

Accepted initial decisions:

| ID | Decision |
|---|---|
| 0001 | React Router v7 Framework Mode is the application framework. |
| 0002 | The portable core targets Web APIs plus SQLite-compatible SQL. |
| 0003 | Local persistence is SQLite; Cloudflare persistence is D1. |
| 0004 | SSE is primary for display updates; SQL events provide replay. |
| 0005 | Durable Objects and other proprietary coordination services are not core dependencies. |
| 0006 | The public product models one installation. Hosted tenancy is private. |
| 0007 | Public and private source live in separate repositories with one-way dependencies. |
| 0008 | Official providers are bundled; workstation data enters through collectors. |
| 0009 | A hosted organization is the tenant and resource-ownership boundary. |
| [0010](0010-external-key-and-audit-authority.md) | Hosted purge and operations audit finality use a separate narrow authority. |
| [0011](0011-pluggable-change-notification.md) | Change notification is pluggable; the transactional SQL outbox is authoritative. |
| [0012](0012-hosted-stripe-billing.md) | Hosted billing uses Stripe at $5 per concurrent seat-month. |
| [0013](0013-hosted-passkey-identity.md) | Hosted identity is passkey-first with verified-email bootstrap and recovery. |
| [0014](0014-remote-control-ready-bridge.md) | An outbound bridge and durable command boundary are reserved now; control is deferred. |
| [0015](0015-managed-server-updates.md) | Managed server updates use a minimal cloud release catalog and constrained local updaters. |
| [0016](0016-update-protocol-and-check-in-records.md) | Releases are identified by ordered version plus git build identity; check-ins are recorded and identification stays optional. |
| [0017](0017-client-sdk-languages.md) | Dart and Swift client SDKs stay experimental, outside the official TypeScript/Python/Go/Rust matrix. |
| [0018](0018-operational-demo-sequencing.md) | An interim operational demo pulled bounded slices of Phases 2–4 forward without closing them. |
| [0019](0019-offline-root-release-trust.md) | Release trust adopts TUF root, targets, snapshot and timestamp roles with an offline threshold root. |
| [0020](0020-managed-oci-updates.md) | Managed OCI updates load a signed image archive through a host-side Compose updater sharing the native operation contract. |
| [0021](0021-agent-connections-and-display-audiences.md) | Personal plugins and organization APIs feed separately authorized dashboard audiences. |
| [0022](0022-release-trust-parameters.md) | Release trust uses a yearly 2-of-3 hardware root, 120-day targets, 7-day online roles, byte-identical mirrors and the root at the tag. |

New consequential decisions should receive a separate numbered Markdown file
describing context, decision, alternatives, consequences, and status. Amend a
decision with a superseding record rather than silently rewriting history.
