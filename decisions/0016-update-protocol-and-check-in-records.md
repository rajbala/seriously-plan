# ADR 0016: update protocol identity and recorded check-ins

## Status

Accepted direction from the owner; implemented in `seriously-cloud` as the
contract half of [Phase 1.5](../MANAGED_UPDATES.md) slice 1. Amends the
check-in privacy wording of [ADR 0015](0015-managed-server-updates.md).

## Context

[ADR 0015](0015-managed-server-updates.md) settled that a minimal cloud catalog
distributes signed release metadata and that the Hub owns the decision to
install. It did not settle three questions the first implementation had to
answer:

1. **What identifies a release.** The owner asked whether releases should be
   tied to the git commit. A commit pins bytes but has no total order, so it
   cannot answer "is an update available"; a version orders but does not pin
   bytes. The existing private release manifest already records `commit`, `tree`
   and `ref` alongside a version tag, so both identities are available.
2. **How a manifest is signed** without the serving Worker holding a signing
   key, given that ADR 0015 separates release-signing permission from ordinary
   catalog serving.
3. **Whether the catalog records who checks.** MANAGED_UPDATES states that
   checks require "no persistent installation identifier or telemetry
   registration". The owner has since asked to record the checking installation
   by IP address, installation identifier and last check time.

## Decision

**Release identity is three fields, each answering one question.** `version` is
the ordering key, `commit` (with `tree`) is the **source** identity, and
`catalogSequence` is the catalog's monotonic view counter. A Hub reporting a
catalog-known version with a different commit is recorded as running an
unrecognized build and is not offered that same version as an upgrade.

A git commit pins source, not the bytes that source produced. Absent
reproducible builds, a locally rebuilt, patched-after-build, or otherwise
compromised artifact can report the official `version`, `commit` and `tree` and
match the catalog exactly. This scheme therefore detects a **mismatched version
claim**, not tampering, and the check response must not be read as attesting to
what is running. The artifact digest in the signed manifest is the identity that
actually covers bytes, and the updater verifies it against the downloaded
artifact at install time. Extending the check payload to report the installed
artifact digest, or a build attestation measured outside the process reporting
it, is the path to real installed-build attestation and is deliberately not
claimed here.

`version` is SemVer 2.0.0 restricted to a bounded subset: no build metadata, a
bounded prerelease grammar, and a shared valid/hostile fixture corpus that every
implementation must pass. Upgrade compatibility is a **half-open interval
object**, not a range expression, so no implementation parses a range grammar.

**The catalog never holds a signing key.** Manifests are signed at publication
over exact bytes in a JWS-shaped detached envelope; the catalog stores and
serves those bytes verbatim, and verifies only with public keys. Publication
requires both an operator bearer secret and a trusted signature — the token
authorizes writing to the catalog, the signature authorizes the bytes as a
release. Neither alone suffices. An update-check response is therefore advisory:
the Hub reaches the same decision itself from the signed manifest, its embedded
trust keys and its durably recorded last-accepted sequence.

**A fresh installation has no recorded sequence, so it gets a bootstrap
anchor.** Otherwise a rolled-back or impersonated catalog could serve any
still-unexpired older manifest to a Hub that has never checked, and the Hub
would accept stale metadata as current. Each build therefore treats the
`catalogSequence` of **its own release manifest** — which it already ships, and
which is signed — as the floor for its first check, refusing anything below it
exactly as it refuses a replay later. `expiresAt` bounds the remaining window,
so the worst case is a freeze no longer than one manifest's validity rather
than an indefinite one. A build predating any release has no floor and must
present its first check as unanchored.

**Check-ins are recorded, identification stays optional, and the record needs a
bound.** The catalog keeps one upserted row per offered installation identifier
(first and last check, count, last reported build and platform, last decision,
last client address) and a daily aggregate that also counts anonymous checks.
Omitting the identifier must not change the decision, the manifest or the
status code, and tests assert the two responses are identical. The identifier
is 128 bits of client-generated randomness, never derived from hardware,
hostname, email or licence, and resettable by the owner. The client address is
read only from the edge-set `CF-Connecting-IP`; a caller-supplied forwarding
header is never read, and an absent address is recorded as absent.

**Neither table is self-bounding, and the aggregate is not an exception.**
Because the identifier is client-chosen, per-installation rows grow one per
distinct identifier: a client that resets its identifier every check, or a
hostile one minting a fresh value per request, inserts a row each time. The
daily aggregate grows one row per distinct
`(day, channel, version, format, os, arch, decision, identified)` bucket, so it
grows without limit across days even when each day is small, and within a single
day its cardinality is bounded by closed enumerations in every field except
`version`, which is client-reported. Both are therefore the same
unbounded-storage objection that rejected the event-row alternative, and both
need an enforceable answer rather than a deferred policy.

Before this service is exposed publicly it must carry, as release gates:

- a **retention window** for each table — deleting an identifier that has
  stopped checking, and deleting aggregate buckets older than the window, which
  bounds the aggregate at (window in days x buckets per day);
- a **cardinality ceiling** past which a new identifier is counted in the
  aggregate only and given no row; and
- a **per-address rate limit**, which is what keeps a single day's bucket count
  near the genuine fleet's version spread rather than near an attacker's
  imagination.

Until those exist, neither table may be relied on as bounded; the aggregate is
merely the slower-growing of the two, because it grows with distinct buckets
rather than with traffic.

**React Router Framework Mode moves to the slice that renders a page.** The
check and manifest endpoints are a JSON resource API on the existing Worker.
Framework Mode remains a Phase 1.5 deliverable for the release page, not a
prerequisite for the contract.

## Alternatives

- **Identify releases by commit alone**: cannot order releases, so "check for
  updates" has no answer.
- **Identify releases by version alone**: cannot detect a tampered or unofficial
  build presenting an official version string.
- **Canonical JSON (JCS) over a parsed manifest**: puts a canonicalization
  implementation inside the trust path. Signing exact bytes removes it.
- **Sign on demand in the Worker**: would place a signing key in the
  request-serving deployment, which ADR 0015 forbids.
- **Full SemVer ranges for upgrade compatibility**: needs a range parser in
  TypeScript, Python and the updater, with three chances to disagree.
- **Require an installation identifier**: would make checking conditional on
  telemetry, which the portability goal rejects.
- **Record nothing**: leaves the operator unable to see version spread, fleet
  size or whether a release is reaching installations.
- **Log every check-in as an event row**: grows with traffic rather than with
  distinct buckets, for a question a daily aggregate answers far more cheaply.
  The aggregate still needs its own retention window, as above; it is the
  cheaper shape, not an escape from retention.

## Consequences

The catalog learns which version and platform are deployed, where from and when,
for installations that choose to say. That is operational telemetry, so it stays
in the private repository and behind no unauthenticated route. Its retention,
cardinality and rate-limit gates — covering the daily aggregate as well as the
per-installation rows — are prerequisites for public exposure, not open-ended
operational follow-ups. MANAGED_UPDATES' "no persistent installation identifier
is required" remains true and is now enforced by test; its stronger reading —
that none is ever recorded — is superseded here.

Compromising the serving deployment still cannot mint a release, because it
holds no signing key. A catalog that is wrong, rolled back or impersonated can
cause a failed or refused check, never an unauthorized installation.

The bounded version grammar means an unusual but valid SemVer string, such as
one carrying build metadata, is refused rather than mis-ordered. Release tooling
must produce versions inside the subset.
