# Engineering standards

These requirements are release gates, not preferences. Each rule must have an
automated enforcement mechanism or a recorded plan to add one.

## Correctness before convenience

- Structured languages and protocols use maintained standards-compliant
  parsers, generated decoders, or schema validators. Regular expressions are
  limited to bounded lexical checks; they do not parse JavaScript, TypeScript,
  HTML, URLs, HTTP fields, source maps, JSON, SQL, OAuth messages, or other
  structured formats.
- External data remains `unknown` until validated at its boundary against a
  canonical, versioned schema. Unchecked casts, partial property probing, and
  hand-written protocol parsers are prohibited when a standard parser or schema
  implementation exists.
- A fallback is permitted only when it preserves documented semantics, has an
  explicit trigger, is observable and bounded, and has positive and negative
  tests. Catch-and-continue, empty-success results, guessed defaults,
  best-effort authorization, and silent capability downgrades are prohibited.
- Unsupported capabilities and invalid configuration fail explicitly during
  setup or at the request boundary. Typed errors distinguish authentication,
  authorization, validation, temporary availability, rate limiting, and
  permanent failure without exposing secrets.

## Architectural restraint

- Use the smallest design that satisfies demonstrated requirements. A new
  service, bus, cache, coordination system, generic abstraction, or cross-cutting
  layer requires an architecture decision record describing its concrete need,
  simpler rejected design, failure modes, portability effect, and exit plan.
- Dependencies point inward. Domain code imports no runtime, database, vendor,
  transport, UI, or private-edition implementation. Global service locators,
  ambient tenant context, arbitrary raw database access, and scattered platform
  conditionals are prohibited.
- Architecture rules are executable through import-boundary checks, schema and
  contract tests, clean-room builds, artifact inspection, and adversarial tests.
- Abstractions must correspond to a stable domain boundary or at least two
  concrete implementations. Premature microservices and distributed
  coordination remain deferred.

## Monorepo-managed SDKs

Every external client uses a versioned public workspace package: display,
collector, remote extension, and administration clients. Applications do not
duplicate authentication, request construction, pagination, retries, error
decoding, SSE cursor handling, or telemetry signing.

Wire schemas are canonical and versioned. SDK types, validators, fixtures, and
compatibility tests are generated from those schemas or share the same source.
SDKs use semantic compatibility rules and negotiate declared protocol
capabilities. CI tests the oldest supported client against the newest server and
the newest client against the oldest supported server. Unsupported major
versions fail with an actionable error instead of guessing.

## Pluggable database layer

Domain services depend on purpose-specific repository and transaction ports,
not a generic query method. Raw SQLite and D1 handles remain inside their
adapters. Both adapters implement identical observable semantics for
transactions, uniqueness, pagination, ordering, concurrency, clocks, and
failure behavior and must pass one public database contract suite.

Migrations are ordered, versioned, forward-tested, and recovery-aware. CI
exercises upgrades from every supported schema. Runtime feature detection cannot
silently choose a weaker correctness path. A future database is added through a
new adapter, migrations, and the same contract suite without modifying domain or
extension packages.

## Extension kinds and security boundary

There is no unconstrained universal plugin interface. The public SDK defines
small extension kinds:

- **provider connector**: authentication, discovery, synchronization, health,
  normalized records, and optional actions;
- **collector**: privacy-scoped workstation or device observations submitted
  through the managed collector client;
- **widget**: browser-safe rendering of declared normalized queries;
- **remote extension**: the versioned HTTPS protocol for services that cannot
  or should not run inside the Hub; and
- **self-hosted process extension**: an optional supervised process using the
  same capability-limited protocol.

Every extension has a declarative manifest with a stable unique ID, kind,
package and protocol versions, runtime compatibility, configuration and secret
schemas, requested host capabilities, produced and consumed record types,
widget registrations, localization and branding, migrations, documentation,
quality status, and code owners. Unknown fields and unsupported requirements
fail validation.

The host grants narrow capabilities for HTTP, secrets, synchronization
checkpoints, events, clock, logging, and declared actions. It never grants a raw
database, filesystem, tenant selector, arbitrary secret access, or private host
internals. Bundled in-process extensions are reviewed. Community-installed
untrusted code runs remotely or in a sandboxed supervised process; the hosted
Worker never dynamically executes third-party packages.

A local process receives a dedicated unprivileged identity, an empty allowlisted
environment, no Hub database, secret, recovery, or host-filesystem mounts, a
read-only executable image, bounded CPU, memory, process, and time resources,
and no ambient network access. All outbound HTTP uses the host capability broker
and its manifest allowlist. The broker resolves through a trusted resolver,
connects only to the validated address, rejects loopback, link-local, private,
metadata, multicast, and otherwise prohibited destinations, and repeats policy
validation for every redirect without forwarding credentials across origins.
DNS answers are pinned for the connection to prevent rebinding. Intentional
private-network access is a separate, prominently approved manifest capability
with its own destination allowlist. Responses have strict connect, first-byte,
idle-read, and total deadlines; encoded and decoded byte ceilings; bounded
redirects; and streaming decompression-ratio limits. Linux deployments enforce
namespaces, syscall
filtering, and a disposable filesystem through the supported sandbox or OCI
runner. If a host cannot provide the required isolation, it supports remote
extensions only and fails local-process installation explicitly.

Normalized records and host-owned queries keep widgets independent of provider
APIs. Extensions cannot add arbitrary server routes or executable markup.
Widget code uses a separate browser SDK, restrictive Content Security Policy,
and safe host components; hostile text, Markdown, HTML, SVG, and URLs are
encoded or sanitized by maintained libraries.

Community widgets are either declarative host-rendered specifications or execute
in sandboxed frames on a separate untrusted origin without same-origin cookies.
The frame receives only declared data through a capability-limited, schema-
validated `postMessage` protocol and cannot navigate the parent, open arbitrary
network connections, or invoke Hub APIs. Bundled reviewed widgets may run in the
Hub bundle but pass the same hostile-content tests.

## Community contribution system

- A scaffold command generates the manifest, typed entrypoint, configuration
  flow, fixtures, tests, docs, diagnostics, localization, and CI metadata.
- A local harness supplies a fake host, clock, HTTP recorder, secret canaries,
  record inspector, setup/reauth flow, and widget preview without real accounts.
- The conformance kit covers schema validation, pagination, rate limiting,
  transient and permanent failures, reauthentication, unload/reload, migration,
  idempotency, checkpoint atomicity, privacy, secret leakage, diagnostics
  redaction, hostile content, and runtime compatibility.
- Contributor documentation includes one complete reference extension and
  focused examples for OAuth, API keys, polling, webhooks, collectors, remote
  extensions, and widgets.
- Each extension declares code owners and a machine-readable quality checklist.
  The acceptance tier requires UI setup, connection validation, strict types,
  tests, removal and reconfiguration, redacted diagnostics, documentation, and
  dependency transparency. Higher tiers add resilience and UX guarantees.
- Exemptions are explicit, justified, reviewed, and stored beside the checklist;
  they are never implicit skips.

## Home Assistant lessons

Adopt its stable manifest identity, integration categories, code ownership,
configuration-entry lifecycle, setup and reauthentication flows, shared
push/poll coordination, stable normalized IDs, redacted diagnostics, and
machine-readable quality scale. These patterns lower contribution and review
cost while keeping integration behavior consistent.

Do not copy an unrestricted custom-component model. Seriously keeps a smaller,
versioned SDK surface and capability boundary so Node, Workers, community
extensions, and private hosted code remain separable.

Reference patterns: [integration manifests][manifest], [configuration-entry
lifecycle][entries], [push/poll coordination][coordinator], [integration quality
rules][quality], and [redacted diagnostics][diagnostics].

[manifest]: https://developers.home-assistant.io/docs/creating_integration_manifest/
[entries]: https://developers.home-assistant.io/docs/config_entries_index/
[coordinator]: https://developers.home-assistant.io/docs/integration_fetching_data/
[quality]: https://developers.home-assistant.io/docs/core/integration-quality-scale/rules/
[diagnostics]: https://developers.home-assistant.io/docs/core/integration-quality-scale/rules/diagnostics/
