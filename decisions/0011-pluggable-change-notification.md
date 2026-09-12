# ADR 0011: Pluggable change notification over a durable SQL outbox

## Status

Accepted.

## Context

Displays need prompt updates on Workers and ordinary self-hosted machines.
Durable Objects efficiently coordinate hosted connections but are unavailable
on-premises. Requiring a separate broker would burden small installations.

## Decision

State changes and ordered outbox events commit atomically in SQLite-compatible
SQL. A `ChangeNotifier` is a replaceable low-latency hint; consumers always
reconcile from the outbox after their scoped cursor. SSE is the stable client
protocol. The public implementation ships database-poll and in-process adapters;
the hosted configuration first uses a per-organization or sharded Durable Object
adapter. Selection is explicit and failed adapters do not silently downgrade.

## Alternatives

- Durable Objects as authoritative storage would bind the domain to Cloudflare.
- Mandatory Redis, NATS, or PostgreSQL would complicate appliance deployment.
- Client polling wastes requests and duplicates synchronization behavior.
- Notification-only delivery loses updates during failure.

## Consequences and exit plan

Notification delivery may duplicate, reorder, or disappear without correctness
loss. Database polling adds bounded latency but requires no extra service.
Durable Objects can hibernate and fan out efficiently while remaining disposable.
Any future adapter must pass the same loss, duplication, ordering, authorization,
reconnection, and shutdown contract suite and can be removed without migrating
authoritative state.
