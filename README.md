# Seriously planning repository

This repository is the public source of truth for the architecture and delivery
plan of Seriously.

- [`seriously`](https://github.com/rajbala/seriously) is the complete,
  open-source, single-tenant product.
- [`seriously-cloud`](https://github.com/rajbala/seriously-cloud) is the private,
  multi-tenant hosted product deployed on Cloudflare Workers.
- `seriously-cloud` may depend on released packages from `seriously`.
  `seriously` must never depend on, fetch, or build private source.

## Documents

- [North-star command-center scenario](PRODUCT_SCENARIO.md)
- [Product and architecture](ARCHITECTURE.md)
- [Public/private repository boundary](REPOSITORY_BOUNDARIES.md)
- [Delivery roadmap](ROADMAP.md)
- [Engineering and extension standards](ENGINEERING_STANDARDS.md)
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

The repositories are newly created. Phase 0 in the roadmap is the next work.
