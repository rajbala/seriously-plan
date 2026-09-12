# ADR 0012: Hosted Stripe billing

## Status

Accepted for the private hosted edition only.

## Context

Seriously Cloud needs simple organization billing without bringing payment-card
handling into Seriously or imposing billing dependencies on self-hosters.

## Decision

The launch price is USD $5 per billable seat-month. A seat-month is the
time-prorated integral of concurrently active human organization memberships;
replacing one member with another at the same instant does not create two seats.
Machine identities and pending invitations are not seats; a person in two
independently billed organizations is one seat in each. Stripe Checkout,
Customer Portal, subscriptions, and monthly proration are the first billing
adapter. Verified idempotent webhooks and scheduled reconciliation update
Seriously-owned entitlement state; browser redirects grant nothing.

## Alternatives

- Flat organization pricing is simpler but poorly matches collaboration growth.
- Usage pricing is harder to predict and couples billing to telemetry.
- Direct card handling creates unnecessary compliance and security scope.

## Consequences and exit plan

Stripe-specific code and secrets remain private. Public packages expose only
vendor-neutral entitlement concepts. Billing outages do not block ordinary
authorization checks against cached authoritative entitlement state, and failed
payments enter grace and suspension rather than deletion. Opaque provider IDs,
an event ledger, and reconciliation permit migration to another billing adapter
without changing tenant or membership identities.
