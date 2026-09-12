# ADR 0013: Hosted passkey identity

## Status

Accepted for the private hosted edition only.

## Context

A global hosted identity can administer several organizations, so password
reuse, phishing, and ambiguous social-provider recovery create broad risk.

## Decision

Seriously Cloud owns its global identity and uses passkeys as the primary
authenticator. A verified, short-lived email link bootstraps an account and
starts delayed recovery. Recovery notifies existing channels, invalidates prior
sessions and attempts, and requires a new passkey before privileged access.
It also revokes or quarantines every authenticator registered before recovery;
a still-trusted device must be explicitly re-enrolled from the recovered session.
Users are prompted to register at least two passkeys. Social login may be an
optional convenience but is never the only recovery authority.

## Alternatives

- Hosted passwords retain phishing, reuse, hashing, and reset risk.
- GitHub-only identity excludes users and makes account recovery depend on one
  integration provider.
- Email links alone make routine authentication depend on inbox security.

## Consequences and exit plan

The service needs reliable email delivery and carefully tested recovery, but
stores no hosted password verifier. Maintained WebAuthn and email libraries are
mandatory. Canonical identity and credential tables remain provider-neutral, so
additional OIDC or enterprise federation can be linked without changing global
user IDs or organization memberships.
