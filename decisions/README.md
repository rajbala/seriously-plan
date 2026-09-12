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

New consequential decisions should receive a separate numbered Markdown file
describing context, decision, alternatives, consequences, and status. Amend a
decision with a superseding record rather than silently rewriting history.
