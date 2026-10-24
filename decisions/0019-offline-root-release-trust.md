# ADR 0019: offline-root key metadata and freshness for release trust

## Status

Accepted on 2026-10-24, as proposed, with the follow-ups below. The owner
delegated the call. It answers the launch blocker recorded in
[MANAGED_UPDATES](../MANAGED_UPDATES.md) and the two open gaps of
[ADR 0016](0016-update-protocol-and-check-in-records.md). It is not required
for an operator-only catalog. It is required before the catalog serves anyone
outside the operator.

## Context

Release manifests are signed with Ed25519 keys whose `notBefore`, `notAfter`
and `revokedAt` metadata reaches a Hub only through configuration. ADR 0016
records two consequences:

1. A key window is judged against the manifest's signer-chosen `publishedAt`,
   so a retired but unrevoked key held by an attacker who also impersonates the
   catalog can mint a release that a fresh installation accepts.
2. `revokedAt` protects a Hub only once it has received the revocation, and no
   authenticated, versioned channel delivers one. An impersonated or rolled-back
   catalog can withhold it.

A third gap appeared in implementation. The operator-run native upgrade in
`seriously` reads trust keys from a `release-trust.json` supplied with each
release and does not compare them with the installed trust root, so every run
can replace the root. The plan instead requires the updater to embed its
verification keys. *Since closed in `seriously`:* a signed installation is now
held to the trust root recorded with it, the host updater never replaces it,
and replacing it takes an explicit `--replace-trust`. The first two gaps
remain.

All three need key metadata signed by an offline root, with versions that
clients persist and refuse to roll back, plus a freshness anchor for a client
that has never checked. These are the root and timestamp roles of The Update
Framework (TUF).

## Decision

Adopt the TUF 1.0 metadata model for release trust, through a maintained
implementation rather than a hand-written subset.

- **Roles.** `root` is offline and threshold-signed; it names the keys and
  thresholds of every other role. `targets` is signed by the release-signing
  keys and lists each signed release envelope by length and SHA-256.
  `snapshot` and `timestamp` are online roles whose keys live in CI, separate
  from release signing, never in the catalog Worker. `timestamp` expires after
  seven days and CI re-signs it daily.
- **Catalog.** The catalog stores and serves TUF metadata verbatim beside the
  existing envelopes and holds no signing key, preserving ADR 0016.
- **Hub and updater.** Each build embeds the root metadata current at its
  release as its trust anchor. Before evaluating any release, the client runs
  the TUF update workflow (root chain, timestamp, snapshot, targets), persists
  each role's version against its trust root and refuses rollback. The
  existing manifest rules (signature, replay, renewal, bootstrap floor,
  compatibility) still apply to the envelope that `targets` names.
- **Rotation and revocation.** Retiring or revoking a release key publishes new
  `targets` delegation in a new root version. Rotating root keys follows the
  threshold-signed root chain. An operator-supplied trust file is accepted only
  for a first installation or an explicit, documented trust-root replacement,
  never as a side input to an upgrade.
- **Failure.** A client that cannot establish freshness, because its timestamp
  expired or the chain cannot be verified, reports why and offers no update. It
  never disables an otherwise working Hub.
- **Libraries.** The TypeScript verifier uses `tuf-js` (maintained by the
  Sigstore project). Any Python updater uses `python-tuf`. `@seriously/updates`
  therefore gains its first runtime dependency, an accepted change to its
  dependency-free design.

With this in place, forging a release needs a release key that the client's
current root still trusts and valid `snapshot` and `timestamp` signatures.
Replaying old metadata is bounded by the timestamp expiry, so the freeze is at
most seven days. Withholding a new root no longer lets a retired key mint a
release.

## Alternatives

- **Hand-written root and timestamp roles over the existing envelope.** This is
  a custom security protocol. The engineering standards require a maintained
  implementation of a reviewed standard, and TUF's rollback, threshold,
  mix-and-match and endless-data rules are easy to get subtly wrong.
- **Sigstore keyless signing.** It adds transparency and identity binding but
  depends on external services and OIDC identities. It needs TUF-style
  freshness anyway (Sigstore distributes its own trust root through TUF). It
  could complement this record later.
- **Short manifest expiry instead of a timestamp role.** This forces frequent
  re-signing with release keys and turns a near-offline key into an online one.
- **Keep operational key custody only.** This is acceptable while the catalog is
  operator-only. It is not acceptable for public exposure, which the plan
  already states.

## Consequences

The owner must hold a root key ceremony with threshold holders and publish a
documented rotation runbook. A scheduled CI job re-signs `timestamp` and
`snapshot`. An update check fetches a few small, cacheable metadata files. An
expired timestamp becomes a visible, fail-closed check outcome. The update
protocol gains versioned metadata endpoints. Existing v1 envelopes remain valid
as TUF targets, so no published release is re-signed. Once accepted, the
"authenticated key metadata" launch blocker in MANAGED_UPDATES closes when
this lands and is tested, including withheld-root, rolled-back-timestamp and
retired-key fixtures.

## Follow-ups

These details are left to the implementation, which must settle them before it
lands. [ADR 0022](0022-release-trust-parameters.md) settles all four.

- **Role expiries.** Only `timestamp` has a stated expiry. Set the others so
  that no near-offline key becomes an online one: `root` at about one year,
  renewed by ceremony; `targets` long enough to span a release cadence and
  re-signed with each release; `snapshot` with `timestamp` in CI. An expired
  `root` or `targets` is a fail-closed check outcome, like an expired
  `timestamp`.
- **Root threshold.** Record the root key count and threshold (for example two
  of three), who holds each key, and how a lost key is replaced.
- **Mirrors.** A configured mirror must relay the TUF metadata unchanged and
  stay fresh enough for the `timestamp` window; document what an air-gapped
  installation does when it cannot.
- **Bootstrap.** Define which root a build embeds when a key rotation happens
  between its tag and its publication.
