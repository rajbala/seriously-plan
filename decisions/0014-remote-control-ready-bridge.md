# ADR 0014: Reserve an outbound bridge and durable command boundary

## Status

Accepted for architecture now; command implementation deferred.

## Context

Users should eventually inspect and control coding agents running behind NAT on
arbitrary machines. Visibility is the immediate product, but adding control
later must not require replacing collectors, realtime delivery, or authorization.

## Decision

The public collector evolves into an outbound-only bridge with vendor adapters,
persistent machine identity, and a common versioned protocol. HTTPS handles
configuration and command creation, displays retain SSE, and a bridge WebSocket
provides low-latency host connectivity. Durable SQL intents and events are the
source of truth; connection routers, including a hosted Durable Object adapter,
are ephemeral hints and routes.

Granular typed capabilities, a durable command state machine, exact payload
digests, expirations, generations, idempotency, acknowledgements, and audit
correlation are reserved in the initial protocol. Content is private by default,
and the envelope can carry a standards-based encrypted payload later. Actual
remote commands are a post-launch phase.

## Alternatives

- Retrofitting commands onto telemetry later risks unsafe authorization and
  delivery semantics.
- Client and bridge WebSockets as the only API would discard the existing
  replayable SSE display contract.
- Peer-to-peer transport adds NAT traversal before message volume justifies it.
- A generic remote shell grants much more authority than agent workflows need.

## Consequences

Early schema and bridge work must pass command-envelope compatibility tests even
while command execution is disabled. Self-hosted and managed deployments share
the protocol. The managed service remains the easiest rendezvous, but is not a
required or authoritative dependency of the open product.
