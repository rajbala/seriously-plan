# Seriously planning repository

This private repository is the source of truth for the architecture and delivery
plan of Seriously. It is not intended for open-source publication.

- [`seriously`](https://github.com/rajbala/seriously) is the complete single-tenant
  product, licensed under Apache-2.0 and intended for eventual open-source publication.
- [`seriously-cloud`](https://github.com/rajbala/seriously-cloud) is the private,
  multi-tenant hosted product deployed on Cloudflare Workers.
- `seriously-cloud` may depend on released packages from `seriously`.
  `seriously` must never depend on, fetch, or build private source.

## Documents

- [North-star command-center scenario](PRODUCT_SCENARIO.md)
- [Product and architecture](ARCHITECTURE.md)
- [Public/private repository boundary](REPOSITORY_BOUNDARIES.md)
- [Delivery roadmap](ROADMAP.md)
- [Next phase: managed server updates](MANAGED_UPDATES.md)
- [Engineering and extension standards](ENGINEERING_STANDARDS.md)
- [Client SDK architecture](SDK_ARCHITECTURE.md)
- [Remote-control-ready architecture](REMOTE_CONTROL.md)
- [Pull-request and Codex review process](PR_PROCESS.md)
- [Initial decision records](decisions/README.md)

## Planning principles

1. The self-hosted product is useful and complete, not a demo or crippled
   edition.
2. The hosted product sells operation, isolation, convenience, and support.
3. Protected-resource credentials never reach a dashboard display.
4. Core application behavior uses portable Web APIs and SQL.
5. Cloudflare-specific APIs do not enter the open domain or provider contracts.
6. Every milestone ends in demonstrable user value and an executable gate.
7. Changes are merged through reviewed pull requests; direct feature commits to
   the default branch are avoided.

## Status

As of October 2026:

- **Phase 0** is complete and released privately as `v0.1.0-alpha.1`, the only
  release so far.
- **Phase 1** is implemented but not closed. Its exit-gate audit, clean private
  installation acceptance and the deferred Windows verification remain; the
  owner has deferred Windows, which the protected release policy still requires
  for the next release.
- Portable installation and onboarding have shipped. The current focus is
  [Phase 1.5 — managed updates](MANAGED_UPDATES.md). Verification, read-only
  owner checks and an operator-run signed native upgrade exist; scheduled checks,
  the narrow host updater with **Update now**, the download broker and managed
  OCI remain. The slice notes there carry the detail.
- An interim [operational demo](decisions/0018-operational-demo-sequencing.md)
  pulled narrow, demo-grade slices of Phases 2–4 forward. Those phases stay open
  with unchanged exit gates.
- `seriously-cloud` serves the release-catalog JSON API and holds an internal
  hosted tenancy foundation for Phase 5; it has no customer surface.

This sequencing does not waive any exit gate.
