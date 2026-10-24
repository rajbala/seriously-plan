# ADR 0017: Dart and Swift client SDKs outside the official matrix

## Status

Accepted on 2026-10-24, as proposed. The owner delegated the call. It records
SDKs that already exist in `seriously` and classifies them.

## Context

[SDK_ARCHITECTURE](../SDK_ARCHITECTURE.md) stages the official languages as
TypeScript and Python (Phase 0), Go (Phase 2) and Rust (Phase 6). It also says a
language is official only when maintainers own its release pipeline, security
updates, compatibility matrix, examples and minimum supported runtime, and that
an experimental generator is not advertised as a supported SDK. The
[roadmap](../ROADMAP.md) defers native mobile applications.

`seriously` has since merged two SDKs that no decision record mentions:

- `flutter/seriously_sdk`, a Dart port of the display and status clients. It
  backs the `seriously-client` Flutter console that the interim
  [operational demo](0018-operational-demo-sequencing.md) uses as its UI.
- `ios/SeriouslySDK`, a Swift port of the Flutter package.

Both derive their models from the canonical `packages/protocol/openapi.json`
(the Dart generator extracts the closed schema graph and fails on unsupported
schema keywords; Swift uses Apple's OpenAPI generator), run the shared protocol
fixtures in their own CI workflows, and label themselves unpublished and
experimental. Neither covers collector submission. No Go or Rust SDK exists.

## Decision

Dart and Swift are **experimental community-tier** SDKs, not official ones.

- The official matrix stays TypeScript, Python, Go and Rust. Dart and Swift do
  not count towards any phase's SDK deliverable or the public-launch support
  matrix.
- They keep consuming the canonical schemas and shared conformance fixtures, and
  a schema change that breaks them fails CI as it does today. Their bindings are
  still generated rather than hand-parsed, as the SDK architecture requires.
- They stay unpublished and labelled experimental until a later decision
  promotes one. Promotion needs everything SDK_ARCHITECTURE requires of an
  official language, including a named owner and a release pipeline.
- An SDK is not an application. Native mobile *applications* remain deferred as
  the roadmap says; these packages give a future client, the demo console
  included, a typed transport without committing to ship one.

## Alternatives

- **Make Dart and Swift official now.** This adds two release pipelines,
  security-update obligations and compatibility matrices before the four
  planned languages exist, and it would make the demo client's language a
  launch commitment.
- **Remove them.** This loses the demo console's transport and the conformance
  signal two extra generators provide, for no correctness benefit.
- **Replace Go or Rust with Dart or Swift.** The planned languages serve
  collectors, host agents and the Lenovo appliance, which mobile languages do
  not.

## Consequences

The matrix in SDK_ARCHITECTURE needs no change; a note there points to this
record. Maintaining the two ports costs CI time and review attention while they
remain experimental. Go and Rust remain open deliverables of Phases 2 and 6.
Promoting either experimental SDK later is a separate, superseding record.
