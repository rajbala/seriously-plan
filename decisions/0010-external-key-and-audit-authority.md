# ADR 0010: External key and audit authority

## Status

Accepted for the private hosted edition only.

## Context

A shared D1 restore must not resurrect purged tenant data or rewrite hosted
operations history. State inside the same rollback domain cannot prove either
property. This requirement does not exist for the single-tenant public product.

## Decision

The hosted edition uses a small separately administered authority outside the
customer D1 backup lifecycle. It stores non-rollbackable tenant-key tombstones
and authorization generations for membership and tenant lifecycle transitions.
It issues monotonically sequenced authenticated receipts and retains replayable
canonical records for every operations audit commit. Destructive operations fail closed when the authority is
unavailable. Access uses workload identity, least privilege, quorum-protected
administration, immutable audit, encrypted geographically separate backups, and
regular restore and reconciliation drills.

The authority exposes narrow tombstone, key-status, authorization-generation,
receipt-append, audit-replay, and verification operations—never dashboard or
provider records or a general database API.
Receipt creation follows an idempotent prepare/finalize protocol with a durable
D1 intent between those phases. The destructive state change occurs only after
finalization and receipt verification, in the same D1 transaction that completes
the intent. Reconcilers abort unused reservations or finish finalized intents;
protocol state distinguishes these from sequence tampering.

## Alternatives

- D1-only key state and hash chains cannot survive rollback of that same D1.
- Periodic external anchors leave a suffix that can be rewritten.
- A general coordination service expands privilege and failure surface.

## Consequences and exit plan

Hosted purge and encrypted customer access depend on this service's
availability. Encrypted tenant reads and writes fail closed during an outage;
no stale cache or lease may outlive a concurrent tombstone. Public status and
other non-customer operations may continue, but no operation may claim purge or
audit finality without a receipt.
The protocol and export format are vendor-neutral so the authority can move to
another transactional, append-only implementation. A dual-write migration must
verify every tenant tombstone and receipt chain before cutover; disaster recovery
must never restore an older authority generation over a newer one.
