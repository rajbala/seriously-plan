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
`catalogSequence` is the catalog's monotonic view counter. The first two are
*immutable release fields*; the sequence is catalog state about a release
rather than part of it, and the renewal rule below turns on that distinction.
A Hub reporting a catalog-known version with a different commit is recorded as
running an unrecognized build and is not offered that same version as an
upgrade.

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

**Replay state belongs to a trust root, not to a URL.** A sequence is only
meaningful within the signing authority that issued it, so the recorded
last-accepted sequence — and the bootstrap floor — are stored against the trust
root they came from. This settles what a *compatible mirror* is: one that serves
the byte-identical signed manifests of the catalog it mirrors. It preserves the
sequence space because it does not issue sequences at all, and a Hub pointed at
one needs no reset. Anything that re-signs under its own trust root with its own
numbering is a different catalog, not a mirror, and switching to it is an
explicit operator action that installs a new trust root and starts that root's
replay state fresh. Without that binding, a mirror whose numbering began below
the official one would have every valid manifest rejected by the floor, and the
same rejection would recur after any catalog change once a higher sequence had
been persisted.

**One rule governs release lifetime.** Manifest `expiresAt`, signing-key
windows and published-version immutability were specified independently and
contradicted each other in two ways: an expired release was unrecoverable,
because every read filters on expiry and publication refused any differing
bytes for a published version, so a pause in cadence could take a whole channel
dark with no operator recourse; and an envelope signed during a rotation
overlap stopped verifying the moment the outgoing key retired, killing a
release the catalog still served.

They are now derived from one decision. A signature is verified against the
manifest's own `publishedAt`, which the signed payload authenticates, rather
than against the time of the check, so a key's `notBefore`/`notAfter` bound when
it may **sign** and its signatures stay valid for the life of the release.
`revokedAt` is a separate emergency lever that invalidates every signature a key
ever made, since a compromised key's past signatures are precisely what an
attacker replays. And publication accepts a **renewal**: identical
immutable release fields — `release`, `notes`, `compatibility` and `artifacts`
— with a later `publishedAt` and `expiresAt` replace the stored envelope in
place, while any other difference remains a conflict. Immutability is about
what a release *is*, not about how long its signed metadata stays fresh — which
is also what makes recovery from a revocation possible without changing any
release.

**A renewal keeps the release's `catalogSequence`.** The sequence orders
releases, and a renewal does not create one. Advancing it would lift a renewed
old release above newer releases in catalog-wide replay order, so a fresh
installation seeded from that renewed manifest would set its bootstrap floor
above the genuine latest release and then reject it as a replay. Freshness
between renewals of one release is carried by `publishedAt` and `expiresAt`,
both of which must move forward.

That ordering is enforced at the catalog, which is not where replay protection
lives, so **the Hub's durable replay state has to carry it too.** Keeping only a
last-accepted sequence was sufficient while every envelope had its own; now that
renewals of one release share a sequence, a rolled-back or impersonated catalog
could serve an earlier renewal and a Hub comparing sequences alone would see
nothing wrong — then fail its checks when that superseded envelope reached the
earlier `expiresAt` it carried. A Hub therefore records, against the trust root:
the highest `catalogSequence` it has accepted, and for each release it has
accepted, that envelope's `publishedAt`. It refuses a lower sequence as before,
and refuses an envelope for a release it already holds whose `publishedAt` is
not later than the one recorded.

**Publication pins `publishedAt` to the catalog's own clock.** It is
authenticated but signer-chosen, so on its own it would let the holder of a
retired key backdate into that key's window and keep minting releases, leaving
`notAfter` bounding nothing. The catalog therefore refuses a manifest whose
`publishedAt` is not close to its own time of publication.

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
- an **eviction policy** for identifiers rather than a first-come ceiling. A
  plain ceiling converts storage exhaustion into denial of registration: a
  hostile client fills it with its own identifiers and keeps them from aging
  out by re-checking each inside the retention window, after which every
  legitimate installation is permanently aggregate-only. Admission must
  therefore evict the least recently seen row so a new installation can always
  displace the coldest one, and the ceiling is meaningful against a determined
  caller only in combination with a fairness or authentication bound;
- a **bucket ceiling** for the aggregate, which the rate limit alone cannot
  supply: a limit is per address, so many addresses — a large IPv6 pool costs an
  attacker nothing — can each spend their quota on different client-reported
  versions and mint a bucket per version, exhausting storage well inside one
  retention window. The `version` field is bucketed only when it names a
  published release; every other value coalesces into one reserved overflow
  bucket, which bounds a day by (published releases + 1) x the closed
  enumerations, with a hard per-day bucket count as a backstop; and
- a **per-address rate limit**, which bounds the cost of producing traffic but
  not the cardinality it can reach, and so supplements the ceilings above rather
  than substituting for them.

Until those exist, neither table may be relied on as bounded; the aggregate is
merely the slower-growing of the two, because it grows with distinct buckets
rather than with traffic. Coalescing unknown versions loses the exact version
string of a development or forged build, which the overflow count and the
per-installation row still record the existence of; that is the intended
trade, since an attacker chooses those strings.

**What these records are not.** The identifier and the reported build both
arrive from an unauthenticated public endpoint, so any caller can mint
identifiers and report published versions while staying inside every ceiling
above. Those ceilings bound storage; they establish nothing about whether a row
corresponds to a real installation. This data is therefore **untrusted
check-request metrics** — enough to notice that a release is reaching
something, useless as a census, and not a basis for any claim about fleet size
or version spread. Turning it into fleet data needs authenticated or attested
installation identity, which trades directly against the optional
identification this record deliberately preserves; that remains an open
decision rather than a settled one.

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
- **Record nothing**: leaves the operator without even the weak signal that a
  release is reaching something.
- **Log every check-in as an event row**: grows with traffic rather than with
  distinct buckets, for a question a daily aggregate answers far more cheaply.
  The aggregate still needs its own retention window, as above; it is the
  cheaper shape, not an escape from retention.

## Consequences

The catalog learns which version and platform are *reported*, from where and
when, by installations that choose to say — a claim about requests, not about a
fleet. That is operational telemetry, so it stays
in the private repository and behind no unauthenticated route. Its retention,
cardinality and rate-limit gates — covering the daily aggregate as well as the
per-installation rows — are prerequisites for public exposure, not open-ended
operational follow-ups. MANAGED_UPDATES' "no persistent installation identifier
is required" remains true and is now enforced by test; its stronger reading —
that none is ever recorded — is superseded here.

**Two gaps in the trust model remain open, and are not closed by this record.**

Pinning `publishedAt` at publication stops backdating *through the catalog*. It
does not make `notAfter` cryptographically binding for a peer facing an
impersonated catalog: the holder of a retired but unrevoked key can still sign
a manifest claiming a time inside that key's window, and a verifier comparing
the window against a signer-chosen field has no independent way to refuse it. A
Hub that has checked before can require `publishedAt` to advance monotonically,
which narrows this to a fresh installation — the same bootstrap position the
sequence floor already has.

`revokedAt` likewise protects a Hub only once it has received the revocation.
This record defines embedded verification keys and replay state for *release
manifests*, but no authenticated, monotonically versioned key metadata. An
impersonated or rolled-back catalog can therefore simply withhold a revocation
and keep serving manifests signed by the compromised key.

Both gaps need the same missing piece: key metadata signed by an offline root,
carrying its own version that clients persist and refuse to roll back, plus a
freshness anchor a client can trust without having checked before. That is the
root-and-timestamp role structure of The Update Framework, and adopting it is a
larger architectural commitment than this record should make on its own. Until
it is decided, the honest statement of the threat model is: a signing key that
is retired but not revoked, in the hands of an attacker who can also impersonate
the catalog, can mint releases a fresh installation will accept. Key custody
after retirement is therefore a live operational requirement, not a formality.

Compromising the serving deployment still cannot mint a release, because it
holds no signing key. A catalog that is wrong, rolled back or impersonated can
cause a failed or refused check, never an unauthorized installation.

The bounded version grammar means an unusual but valid SemVer string, such as
one carrying build metadata, is refused rather than mis-ordered. Release tooling
must produce versions inside the subset.
