# ADR 0018: an interim operational demo ahead of the phase order

## Status

Accepted direction from the owner, recorded retroactively. The milestone is
defined in `seriously` as `docs/demo-milestone.md` and was implemented through
reviewed pull requests before this record existed.

## Context

The [roadmap](../ROADMAP.md) delivers phases in order: each must pass its exit
gate before the next becomes the primary focus. While Phase 1 was still open,
the owner asked for a working end-to-end view of real agent and GitHub activity
on a paired client, which needs narrow pieces of Phases 2, 3, 4 and 6.

That milestone shipped in `seriously` as:

- canonical operational projection schemas and shared SDK validation;
- scoped collector enrollment, revocation and bounded idempotent ingestion;
- Claude Code collection from native hooks and opt-in OTLP telemetry, and Codex
  activity from native hooks, without parsing terminal output or prose;
- read-only GitHub polling of open pull requests, reviews and current-head checks
  using a fine-grained personal access token and an owner-triggered refresh;
- database-polled change notification and display live reconciliation; and
- the `seriously-client` Flutter console as the demo UI.

Later work extended the same path with installable agent plugins, guided
onboarding and private personal usage analytics.

## Decision

The operational demo is an explicitly bounded interim milestone, not a phase.

- Pieces it delivered count towards their phases only where they meet that
  phase's stated deliverable. They do not close any phase or satisfy any exit
  gate on their own.
- Demo-grade substitutes are recorded as substitutes. GitHub access by personal
  access token and manual refresh does not replace Phase 2's least-privilege
  GitHub App, verified webhooks, scheduled reconciliation and outbound broker.
  Collector ingestion does not replace Phase 4's bridge, attention rules or
  host and deployment collectors.
- Authentication, bounded input, generation fencing, deduplication and
  credential and content isolation still apply to demo code, as the milestone
  itself requires.
- The phase-order rule continues to govern primary focus. A future interim
  milestone needs its own record before work starts.

## Alternatives

- **Hold the demo until its phases are complete.** This would have delayed any
  live end-to-end feedback until after Phase 4.
- **Renumber the roadmap around the demo.** This would blur which gates remain
  open and break references across both repositories.

## Consequences

Phases 2, 3 and 4 now start with working but partial code: their remaining
deliverables are tracked against these substitutes rather than from zero. The
demo's surfaces (collector routes, GitHub connection, personal analytics) must
still enter the Phase 1 and later request-level authorization and CSRF
inventories as they become enabled routes. The Dart and Swift SDKs that serve
the demo client are classified separately in
[ADR 0017](0017-client-sdk-languages.md).
