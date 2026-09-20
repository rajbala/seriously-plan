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
the ordering key, `commit` (with `tree`) is the build identity, and
`catalogSequence` is the catalog's monotonic view counter. A Hub reporting a
catalog-known version with a different commit is recorded as running an
unrecognized build and is not offered that same version as an upgrade.

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

**Check-ins are recorded, and identification stays optional.** The catalog keeps
one upserted row per offered installation identifier (first and last check,
count, last reported build and platform, last decision, last client address) and
a bounded daily aggregate that also counts anonymous checks. Omitting the
identifier must not change the decision, the manifest or the status code, and
tests assert the two responses are identical. The identifier is 128 bits of
client-generated randomness, never derived from hardware, hostname, email or
licence, and resettable by the owner. The client address is read only from the
edge-set `CF-Connecting-IP`; a caller-supplied forwarding header is never read,
and an absent address is recorded as absent.

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
- **Log every check-in as an event row**: unbounded growth for a question a
  daily aggregate answers.

## Consequences

The catalog learns which builds are deployed, where from and when, for
installations that choose to say. That is operational telemetry, so it stays in
the private repository, behind no unauthenticated route, with retention policy
tracked alongside the rest of the hosted telemetry work. MANAGED_UPDATES' "no
persistent installation identifier is required" remains true and is now enforced
by test; its stronger reading — that none is ever recorded — is superseded here.

Compromising the serving deployment still cannot mint a release, because it
holds no signing key. A catalog that is wrong, rolled back or impersonated can
cause a failed or refused check, never an unauthorized installation.

The bounded version grammar means an unusual but valid SemVer string, such as
one carrying build metadata, is refused rather than mis-ordered. Release tooling
must produce versions inside the subset.
