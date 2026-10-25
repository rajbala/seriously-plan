# ADR 0023: Each self-hosted installation registers its own GitHub App

## Status

Accepted on 2026-10-25. The owner delegated the call; it was proposed with the
[Phase 2 plan](../PROVIDER_PLATFORM.md) and is accepted as proposed when slice
4 starts. The owner can still reverse it by superseding this record.

## Context

Phase 2 replaces the demo's GitHub CLI login with least-privilege GitHub App
authentication. A GitHub App has one private key and one webhook secret, and
its setup redirect and webhook URL point at a single deployment. Seriously's
self-hosted edition must not depend on a cloud account to operate, and the
release catalog already avoids holding installation credentials.

## Decision

Each self-hosted installation creates its own GitHub App through GitHub's App
manifest flow. Seriously generates a versioned manifest with only the
documented read-only permissions and the installation's own callback and
webhook URLs. The manifest code exchange returns the private key and webhook
secret, which go directly into the installation's provider secret store. Both
the manifest exchange and the installation setup redirect carry high-entropy,
single-use, expiring state bound to the session, installation and provider
configuration. The hosted service will operate one shared App in Phase 5; that
is a separate decision.

## Alternatives

- **One shared Seriously App for self-hosted users.** Its private key would sit
  with the operator, every webhook would route through Seriously's
  infrastructure, and self-hosted operation would depend on the cloud.
- **Keep fine-grained personal access tokens.** Simple, but tied to one user,
  no webhooks, no installation-scoped permissions, and ADR 0018 records them as
  a demo substitute.
- **Manual App creation from written steps.** Works, but error prone; the
  manifest flow sets permissions exactly and still allows a manual fallback.

## Consequences

The App permission allowlist check runs against Seriously's generated
manifest. Owners see the App as theirs in GitHub and can revoke it there;
uninstallation is a terminal provider state, not an error to retry. An
installation without a public hostname can still register and poll, without
webhooks. Moving an installation to a new hostname requires updating the
App's URLs, which the settings page documents.
