# Client SDK architecture

Seriously's protocol is language-neutral. TypeScript types are an output of the
protocol toolchain, never the source of truth. Canonical OpenAPI 3.1 documents,
JSON Schemas, and explicit SSE event schemas define HTTP resources, commands,
errors, cursors, snapshots, and live updates for both self-hosted and hosted
deployments.

## Trust-scoped SDK families

The public monorepo owns distinct SDK families rather than one universal client:

- **display** enrolls a screen, reads its authorized dashboard projection,
  consumes snapshot-plus-SSE updates, resumes from cursors, falls back to
  bounded polling, and exposes stale/offline state;
- **collector** enrolls a producer and submits validated observations, usage
  aggregates, heartbeats, and idempotent checkpoints;
- **extension** implements remote connector and process-extension protocols
  through capability-limited host services;
- **administration** manages dashboards, integrations, displays, users, and
  installation settings for an authenticated human; and
- **widget** renders normalized, display-authorized view models without gaining
  provider, collector, secret, database, or administrative access.

Applications import only the narrow SDKs they need. In particular, the Lenovo
Cage client imports the display and widget packages only. Dependency-graph and
artifact-inspection gates reject display bundles containing administration,
collector, provider-secret, database-adapter, or private-edition code.

The display SDK is the stable interface for actual dashboard clients. It owns
device enrollment and credential rotation, capability and protocol negotiation,
snapshot validation, ordered event application, cursor persistence, reconnect
backoff, bounded polling fallback, revocation, and typed degraded-state signals.
It returns normalized dashboard view models; it never exposes provider tokens or
raw provider responses. The visual shell, layout, touch behavior, and Cage or
browser lifecycle remain application concerns above that SDK.

## Multiple languages from one contract

Each language package contains generated models, validators, transport bindings,
fixtures, and error types plus a deliberately small hand-written idiomatic layer
for lifecycle and streaming behavior. No implementation hand-parses JSON, SSE,
URLs, OAuth messages, or error bodies. Generator templates and handwritten code
live in the public monorepo and are tested against the same recorded conformance
suite.

The initial official language matrix is staged so neutrality is proven early:

| Milestone | Official SDK work |
|---|---|
| Phase 0 | Generate and contract-test TypeScript and Python display/collector clients. |
| Phase 2 | Add Go clients and publish the extension conformance harness. |
| Phase 6 | Add Rust clients and exercise the Lenovo display against the public display contract. |
| Public launch | Support TypeScript, Python, Go, and Rust under one documented compatibility policy. |

Additional community languages use the same schemas, protocol fixtures, and
conformance service. A language is called official only when maintainers own its
release pipeline, security updates, compatibility matrix, examples, and minimum
supported runtime. An experimental generator is not advertised as a supported
SDK.

## Compatibility and releases

SDK and protocol versions are independent but declared together. Clients send
their supported protocol range and required capabilities; servers select a
compatible version or return a typed, actionable incompatibility error. They do
not silently discard fields or downgrade security behavior. CI exercises every
official language against Node/SQLite and Workers/D1, newest server versus the
oldest supported client, newest client versus the oldest supported server, SSE
loss/replay/reordering, polling fallback, revocation, and hostile payloads.

Generated artifacts are reproducible and provenance-attested. A schema change
must update compatibility fixtures and every affected official language in the
same monorepo pull request. Hosted-only APIs and types are generated and released
from the private repository; they cannot enter public SDK source, packages,
fixtures, documentation, or generated artifacts.
