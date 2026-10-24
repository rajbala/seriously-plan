# ADR 0020: managed OCI updates through a host-side Compose updater

## Status

Proposed for the owner's decision. It shapes slice 5 of
[MANAGED_UPDATES](../MANAGED_UPDATES.md). It reuses the operation contract the
native host updater established in `seriously`, so it should follow that
slice's review rather than precede it.

## Context

The plan asks for a managed OCI adapter that replaces only the registered
Seriously container with an image pinned by digest, preserves the declared data
volume, configuration, network and certificate bindings, documents a bounded
Compose topology, and never gives the web server the Docker socket.

The native slice settled the contract the OCI adapter should share. The Hub
runs a fresh check, downloads the release through the catalog's broker, checks
its digest while it keeps serving, and leaves the release with a request in its
own data directory. A root updater takes bounded copies, verifies them again
against the trust root recorded with the installed release, applies them with
rehearsed migrations, verified backups and recovery, and records each stage
where the Hub can read it and cannot change it. Releases are private GitHub
release assets identified by asset, never by URL, and there is no image
registry anywhere in the trust path.

A Compose installation keeps its data in the named volume `seriously-data`,
runs the Hub as an unprivileged user without capabilities, and today builds
its image locally.

## Decision (proposed)

- **Artifact.** A release carries an OCI image archive for linux/x86_64
  (`seriously-oci-linux-x86_64.tar`) as a private release asset, described in
  the signed manifest as format `managed-oci`, recipe `managed-oci@1`, with its
  byte size and SHA-256 like the native archive. The image is identified by its
  config digest, read from the verified archive before loading; no tag, name or
  registry is trusted. Release CI builds it from the protected tag beside the
  native archive, scans it and includes it in the release candidate.
- **Topology.** One supported Compose project: the shipped `compose.yaml`, with
  the `hub` service's image taken from the project's `.env` by image ID and
  `pull_policy: never`, and the updater's record directory bind-mounted
  read-only so the Hub reads records it cannot change. Volumes, the TLS bind
  and ports stay as they are.
- **Updater.** A root path unit and oneshot service on the Docker host, as for
  native. An operator registers it once with the Compose project directory and
  the trust root (catalog origin and keys) that every later update is held to;
  rotating that root is a deliberate operator action. It reads nothing from a
  request but the release files and the confirmed version, never a path,
  command, image or URL.
- **Operation.** The same stages and refusals as native: verify the signature,
  freshness, upgrade interval, required updater, confirmed version and the
  archive's digest, structure and config digest; load the image; rehearse the
  migrations by running the new image against a copy of the database in a
  scratch volume; stop `hub`; back up the data volume with the installed image
  into a root-only directory and verify the copy; migrate with the new image;
  switch `.env` to the new image ID; start in maintenance with the readiness
  check; confirm the running image ID and release identity; reopen writes;
  record the outcome.
- **Recovery.** The boundary is the reopening of writes, as the plan requires,
  not the start of the new version. The new image starts in maintenance: it
  answers readiness and reports its release identity but admits no writes, and
  the updater reopens writes only after confirming both. A failure before then,
  including a failed readiness or identity check, restores the verified backup
  and the previous image ID under the existing restore fencing rules and starts
  that. After writes reopen, going back is an explicit operator recovery with a
  data-loss warning. The previous image is kept until the next successful
  update.
- **Scope.** Docker Engine with Compose v2 on Linux x86_64. Rootless Docker,
  Podman, Swarm and Kubernetes keep checks with instructions.

## Alternatives considered

- **Pull by digest from a registry.** Adds a second distribution channel and a
  registry credential beside the broker that already authorizes downloads.
- **An updater container with the Docker socket.** Equivalent to root on the
  host, inside an image the update itself replaces.
- **A Watchtower-style puller.** No signature verification, migration
  rehearsal or recovery.

## Consequences

- Release CI produces and scans a second artifact; the catalog serves it through
  the existing download route unchanged.
- The Compose topology changes once, and existing Compose installations adopt it
  by hand before they can be managed.
- The Hub needs a maintenance start that keeps writes closed until the updater
  reopens them. Native lacks it today: it starts the new version serving, so a
  readiness failure after the start goes to an operator. Native adopts the same
  start, which brings both adapters to the plan's recovery boundary.
- The exit gate gains a CI job with Docker that updates a Compose installation
  between two signed fixture releases, refusing tampered and unconfirmed ones
  and recovering from a release that cannot start, mirroring the native job.
