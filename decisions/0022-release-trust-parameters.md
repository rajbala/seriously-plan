# ADR 0022: Release-trust role expiries, root custody, mirrors and bootstrap

## Status

Accepted on 2026-10-24. The owner delegated the call. It settles the four
follow-ups that [ADR 0019](0019-offline-root-release-trust.md) left to the
implementation, which must follow these values or amend this record. It does
not change ADR 0019's decision.

## Context

ADR 0019 adopts the TUF 1.0 roles for release trust and fixes one number: the
`timestamp` role expires after seven days and CI re-signs it daily. It leaves
open the other role expiries, the root key count, threshold and custody, how
mirrors and air-gapped installations stay fresh, and which root a build embeds
when a rotation lands between its tag and its publication.

Some facts constrain the answers. Seriously is run by one owner. A release
manifest's `expiresAt` is set about 90 days after `publishedAt`, and the
**Release catalog** workflow re-signs it on a renewal dispatch. That workflow
signs at publication time, in the `release-catalog` environment, which needs
the owner's approval for each run. A scheduled job cannot wait for an approval,
so whatever CI re-signs daily must live in a separate environment.

## Decision

### Role expiries

| Role | Expiry | Signed | Keys and threshold |
|---|---|---|---|
| `root` | 365 days | By ceremony, yearly and on any key change | 3 offline keys, 2 to sign |
| `targets` | 120 days | With each release and each renewal | Release-signing key, 1 |
| `snapshot` | 7 days | Daily by CI, with `timestamp` | Online key, 1 |
| `timestamp` | 7 days | Daily by CI (ADR 0019) | Online key, 1 |

- `root` is renewed by a ceremony at least 60 days before it expires.
- `targets` is re-signed whenever a release is published or renewed, in the same
  approved run that signs the envelope. A manifest expires after about 90
  days, so a release or renewal happens at least that often, and 120 days
  leaves 30 days of slack.
- `snapshot` and `timestamp` share one online key in a `release-freshness`
  environment. It admits only the default branch and the scheduled workflow,
  and holds no release-signing key.
- A scheduled check opens an issue when `root` has fewer than 60 days left,
  `targets` fewer than 30, or the latest `timestamp` is more than two days old.
- Every expiry is judged against the Hub's clock. An expired `root`, `targets`,
  `snapshot` or `timestamp` is a fail-closed check outcome that names the role.
  As TUF specifies, only the newest root in the chain must be unexpired, so a
  build whose embedded root has since expired still updates through the chain.

### Root keys and custody

- **Three keys, two to sign.** One lost key does not stop a rotation, and one
  stolen key cannot sign a root.
- **Hardware only.** Each key is generated on its own hardware token and cannot
  be exported, so no copy exists to leak. Root keys use ECDSA P-256 (TUF's
  `ecdsa-sha2-nistp256`), because that is what PIV tokens and the PKCS#11
  signer in `python-tuf`'s `securesystemslib` support widely. Release and online
  keys stay Ed25519.
- **Holders.** The owner holds all three keys, in separate places: one with
  them, one in a home safe and one off-site, such as a safe-deposit box. With
  one owner, handing a key to someone else adds a person to trust but no
  independent judgment. When a second maintainer joins, the off-site key
  moves to them.
- **Ceremony.** Signing happens on a machine with networking off. The unsigned
  root is produced from a reviewed pull request to `seriously`, and the signed
  result is merged back. Each ceremony records the date, the root version, the
  key IDs used, and the reason in the rotation runbook.
- **A lost or stolen key.** The two remaining keys sign a new root version that
  drops it and adds a new key. Theft also rotates the release and online keys
  as a precaution. If two keys are lost, the chain cannot continue: a new root
  ships only through the explicit trust-root replacement that ADR 0019 already
  allows, and installations adopt it by an operator action.

### Mirrors and air-gapped installations

- **Consistent snapshots.** The repository publishes with
  `consistent_snapshot` on, so every `snapshot`, `targets` and target file is
  named by version or hash and a mirror never serves a mixed set mid-sync.
- **Relay, never re-sign.** A mirror serves every TUF metadata file
  byte-identical, including every past `N.root.json`, and syncs at least every
  24 hours. A mirror that falls more than seven days behind makes checks
  through it fail closed as stale. The Hub reports the mirror as the reason,
  and that is the intended result. A mirror that re-signs is a different
  catalog, as the update protocol already says.
- **Air-gapped installations.** The supported path is an offline update
  bundle: a connected machine exports the full metadata set, the target
  envelope and the artifact, and the operator carries it to the installation.
  The Hub verifies the bundle with the ordinary TUF workflow, freshness
  included, so the bundle must be applied before the earliest expiry among
  the newest `root`, `targets`, `snapshot`, `timestamp` and the envelope. Older
  roots ride along for the chain walk and, as TUF specifies, may be expired,
  so they never shorten the deadline.
  Exporting does not renew any signature, and `timestamp` usually governs: a
  bundle exported right after the daily re-signing has nearly seven days, and
  one exported just before it about six. The exporter prints that deadline
  and refuses to export when less than three days remain. A bundle past its
  deadline is refused, and the operator exports a fresh one. There is no
  freshness bypass. Before the bundle tooling exists, an air-gapped
  installation reports that freshness cannot be established and offers no
  update, as ADR 0019 specifies.
- **Clock.** An air-gapped Hub depends on its own clock for every expiry. The
  installation guide says so, and a check reports a clock earlier than the
  build's own release time as a fault instead of trusting it.

### Which root a build embeds

- **The root at the tag.** A build embeds the root metadata committed in
  `seriously` at its tagged commit, and never fetches one at build time, so
  the build stays reproducible from the tag.
- **A later rotation is harmless.** A Hub walks the root chain from its
  embedded version to the newest on its first check, so a rotation between
  tag and publication needs no rebuild.
- **Publication checks the chain.** The release-catalog job refuses to publish
  when the embedded root is not byte-identical to that version in the
  catalog's chain, or is newer than the catalog's latest root. A new root
  version is therefore published before any release that embeds it. A build
  embedding a root from outside the chain, after a two-key-loss reset, is
  re-tagged.
- **Release keys follow publication.** The envelope and `targets` are signed
  at publication with the key the current root delegates to. A release-key
  rotation between tag and publication therefore needs no rebuild either.

## Rationale

- **Expiries.** Each expiry follows from how often its key can sign without
  becoming an online key. `root` needs a person and hardware, so yearly with a
  60-day window. `targets` needs the owner's approval, so it rides the release
  and renewal runs that already need it. `snapshot` and `timestamp` are the
  only roles CI signs unattended, so they carry the short window that bounds
  a freeze attack to seven days.
- **Two of three.** It is the smallest threshold that survives both a lost key
  and a stolen key. Three of five adds hardware and places to manage for one
  person, with no new protection.
- **P-256 for root.** The root is the one role that must live on hardware, and
  P-256 is the curve that hardware signs reliably today. TUF verifies both
  curves, so mixing them costs nothing.
- **One online key for two roles.** Both live in the same environment, so a
  compromise there gets both keys anyway. One key halves the rotation work and
  loses nothing.
- **No freshness bypass for air-gapped installations.** A bypass is the replay
  that ADR 0019 exists to stop. Six days is ample to carry a bundle.
- **Embed at the tag, check at publication.** Embedding at the tag keeps
  builds reproducible. TUF's chain walk is what makes an older embedded root
  safe, so the one thing to enforce is that the chain is unbroken, and the
  publication step is where that can be checked.

## Alternatives

- **Root expiry of several years.** It means fewer ceremonies, but a lost key
  could go unnoticed for years. A yearly ceremony also tests the holders.
- **Targets on CI with a short expiry.** This turns the release key into an
  online key, which ADR 0019 rejects.
- **One root key.** A single lost token would end the chain, and every
  installation would need a manual trust replacement.
- **A freshness override for air-gapped installations.** Rejected above.
- **Embed the newest root at publication.** This changes a built artifact
  after its tag, or delays publication for a rebuild, to gain nothing that the
  chain walk does not already give.

## Consequences

The owner buys three hardware tokens, holds the first ceremony before the
catalog serves anyone outside the operator, and stores the tokens as above. The
owner also creates the `release-freshness` environment and its online key. The
TUF implementation in `seriously` and `seriously-cloud` takes these values as
its specification: the expiry table, the scheduled freshness job and expiry
warnings, consistent snapshots in the catalog, the publication-time chain
check, and fixtures for an expired embedded root reached through the chain, a
mirror more than seven days stale, and a stale offline bundle. The offline
bundle exporter is part of that work.
