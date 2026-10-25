# ADR 0024: Root keys without hardware tokens

## Status

Accepted on 2026-10-25. The owner declined to rely on hardware tokens and
delegated the replacement. This record amends the custody part of
[ADR 0022](0022-release-trust-parameters.md): its "Hardware only" rule, its
signing machine and the consequence that the owner buys three tokens. Every
other value in ADR 0022 stands, including three root keys with two to sign,
ECDSA P-256 for root, the holders and the yearly ceremony.

## Context

ADR 0022 required each of the three root keys to be generated on its own
hardware token, such as a YubiKey, so that no copy could exist. The owner
does not want release trust to depend on buying, keeping and replacing such
devices. Seriously must also stay deployment-agnostic, so the replacement
cannot name one cloud provider's key service as the only way to hold a key.

What the root needs from its keys is that one leaked or lost key can neither
sign a root nor stop a rotation. The threshold supplies that, provided the
three keys fail independently. The ceremony tooling already accepts any
ECDSA P-256 signature over the root's signing payload, whatever made it.

## Decision

- **Any of two kinds of key.** Each root key is either a **sealed key file**
  or a key in a **signer that never exports it**: a key management service of
  any provider, an HSM, or a hardware token for an owner who wants one. Keys
  of either kind mix freely in one root. They stay ECDSA P-256
  (`ecdsa-sha2-nistp256`), so a later move from one kind to the other is an
  ordinary root rotation.
- **Sealed key files are the default.** `release-trust generate-root-key`
  creates the key and seals it under a passphrase that the owner chooses, of
  at least 15 characters. The seal uses scrypt (N = 2^17, r = 8, p = 1) and
  AES-256-GCM. The public key is stored in the clear, so drafting a root
  needs no passphrase. Every parameter is authenticated, so an altered file,
  including one claiming a cheaper key derivation, fails to open. The private
  key never touches disk unsealed. `release-trust sign-root` unseals it in
  memory for one signature.
- **Independence.** No two root keys may be reachable through the same
  thing. That means two files may not share a passphrase, a drive or a
  storage location, and two service keys may not share an account or a
  credential. Each sealed file's passphrase lives apart from the file, for
  example in the owner's password manager while the file sits on offline
  media. Either one alone opens nothing, so a backup copy of a file adds no
  exposure.
- **Holders and places.** The owner still holds all three keys in three
  places, as ADR 0022 says. With sealed files, "a key" means its file and its
  passphrase.
- **Signing machine.** A sealed file is unsealed only on a machine with
  networking off. A service key signs wherever the service is reachable. Only
  the root's signing payload is sent to it, and only the signature comes back.
- **Lost and exposed keys.** A forgotten passphrase is a lost key. A file
  that may have been copied together with its passphrase is a stolen key.
  Both follow ADR 0022's procedure: the two remaining keys sign a new root
  that replaces it.

## Rationale

- **The threshold does the work hardware did.** With 2 of 3, an attacker
  needs two keys. For sealed files, that means two files and two
  passphrases, kept in different places. Hardware made a single key
  uncopyable. The threshold makes a single copied key insufficient, which is
  the property the root needs.
- **Sealed files fail less often than tokens.** A token that breaks or is
  lost takes its key with it. A sealed file can be backed up as often as
  wanted without weakening it, so the remaining risk of loss is a forgotten
  passphrase, which a password manager covers.
- **Provider-agnostic.** A file needs no account anywhere. A key service is
  an option for an owner who already has one, and the tooling accepts its
  signatures without code for any particular provider.
- **scrypt at 2^17.** A key that is opened about once a year can afford a
  second of work and 128 MiB per guess. With a 15-character minimum, guessing
  a passphrase costs far more than the key is worth.

## Alternatives

- **Keep hardware tokens only.** This is the strongest custody for a single
  key, but the owner declined to depend on it.
- **One cloud provider's KMS for all three keys.** One account compromise or
  closure would then reach every key, which breaks the independence the
  threshold needs. It would also tie release trust to one provider.
- **Unencrypted offline key files.** Anyone who finds or copies a file would
  hold that key. That is fine for one key under a 2-of-3 threshold, but
  sealing costs nothing and removes the risk.
- **More keys, such as 3 of 5.** This adds places to manage for one person,
  and independent passphrases already give the protection it would add.

## Consequences

The owner creates three root keys before the first ceremony, by default
three sealed key files with three passphrases kept in three places. No device
purchase is needed. `seriously` gains the `generate-root-key` and `sign-root`
ceremony commands, and it accepts DER public keys as key services export
them. The runbook in `docs/release-trust.md` describes both kinds of key and
the independence rule. ADR 0022's expiries, threshold, mirror, bundle and
embedding decisions are unchanged.
