# Remote-control-ready architecture

## Decision and timing

Seriously is designed now so remote control can be added without replacing the
collector, protocol, authorization, audit, or realtime foundations. Initial
releases remain visibility-first. Remote approvals, instructions, and
cancellation are implemented only in a post-launch phase after session discovery
and attention state are reliable. Remote agent launch remains separately deferred
until an adapter can expose it as a narrow structured capability.

The normal managed experience is an outbound-only open-source bridge connecting
agent hosts to Seriously Cloud. The same bridge can target a self-hosted Hub or
loopback local mode. No normal mode requires inbound firewall rules, a public
host address, VPN, dynamic DNS, UPnP, or peer-to-peer NAT traversal.

```text
agent adapter <-> open bridge == outbound TLS ==> Hub <== HTTPS/SSE ==> client
                                             later: authorized commands ---->
```

The Hub is a rendezvous and control plane, never an agent execution environment.
Source trees, shells, tools, provider credentials, compilers, and agent processes
remain on the enrolled host.

## Bridge and adapter boundary

The bridge evolves from the collector daemon rather than creating a second host
agent. It owns machine enrollment, a persistent machine identity, outbound
connection lifecycle, presence, cursor/checkpoint persistence, adapter discovery,
and routing. Vendor adapters own structured integration with Claude Code, Codex,
OpenCode, and future agents.

Adapters use official local APIs, SDKs, hooks, or versioned structured metadata.
Terminal scraping and regular-expression interpretation of agent prose are not a
fallback. An adapter without reliable structured evidence reports an unsupported
capability or `unknown` state.

Capabilities are granular, typed, and default-deny, such as
`session.observe`, `approval.resolve`, `session.cancel`, or
`instruction.submit`. Advertising `shell`, `filesystem`, or `git` does not grant
arbitrary access. A future general shell or file operation would be a separate
high-risk capability and decision with explicit user approval and policy.

## Transport and durable state

Configuration and command submission use HTTPS. Display and ordinary browser
updates continue to use the existing snapshot-plus-SSE contract. A bridge may
hold one outbound authenticated WebSocket for low-latency presence, events, and
later command delivery. Clients do not require WebSockets merely because bridges
use them; a future bidirectional client transport must implement the same command
contract and authorization semantics.

SQL command intents, normalized records, events, acknowledgements, and audit
records are authoritative. A connection router maps a logical installation,
organization, machine, and connection generation to an ephemeral live transport.
The first hosted router may use a Durable Object and the Node adapter may use an
in-process WebSocket registry, but neither owns unrecoverable session state or
pending commands. Connection loss is repaired from durable cursors and current
state. R2 or any other object store is an optional private storage adapter, not a
public protocol dependency.

## Machine enrollment and identity

On first enrollment the bridge generates a machine key pair locally and proves
possession while the user approves a short-lived, single-use device code in an
authenticated client. The private key remains in the operating-system credential
store or a permission-restricted secret backend. The Hub stores the public key,
machine identity, owner scope, platform, approved capabilities, key generation,
and revocation state. Reconnect uses a fresh server challenge signed by the
machine key; replay, cloned identity, stale generation, and revoked keys fail.

Machine identity is distinct from a human, display, collector, adapter, and
session. Hosted machines belong to an organization, not directly to an
unscoped global user. Access is determined by organization membership and named
capabilities. Self-hosted and local modes use the same identifiers and protocol.

## Command contract reserved now

Every remotely controllable adapter action implements a common command state
machine even before any UI exposes it:

`requested -> authorized -> deliverable -> delivered -> acknowledged -> completed`

Terminal outcomes are `rejected`, `expired`, `cancelled`, `failed`, and
`indeterminate`. A command has a globally unique request ID, target installation
or organization, machine, session, adapter action, schema version, creation and
expiry instants, authorization and session generations, exact payload digest,
idempotency key, actor, required capability, and audit correlation ID.

The Hub authorizes and durably records a command before routing it. The bridge
accepts only commands for its current machine and connection generations, an
approved adapter capability, a valid unexpired envelope, and a request ID not
already applied. The adapter returns a typed acknowledgement and durable outcome.
A timeout after a possibly applied non-idempotent operation becomes
`indeterminate`; the Hub never guesses, silently retries, or reports success.

Approvals bind to the exact agent-generated approval ID, proposed operation,
session, machine, expiry, and observed agent state. Instructions and cancellation
are different capabilities. Dangerous commands require recent human
authentication and policy approval. Offline approval and other security-sensitive
commands expire rather than queue indefinitely.

## Privacy and future end-to-end encryption

Presence and status use normalized metadata. Prompts, transcripts, terminal
output, diffs, source, and message bodies remain off by default and require
separate informed consent and retention controls. The managed service may inspect
consented plaintext initially, but the version-one envelope separates visible
routing metadata from a versioned payload, binds authorization to its digest,
and carries sender, recipient-key, algorithm, and payload-format identifiers.
That permits a later standards-based end-to-end encrypted payload without
changing routing, command identity, acknowledgement, replay, or audit models.
Cryptography will use a maintained implementation of a reviewed standard, not a
custom construction.

## Deployment and repository boundaries

The public `seriously` repository owns the bridge, adapters, protocol schemas,
SDKs, portable rendezvous contracts, Node/SQLite and single-tenant Workers/D1
implementations, and conformance tests. The private `seriously-cloud` repository
adds multi-tenant identity, organization routing, Durable Object topology,
billing, abuse controls, managed notifications, and operations. Public code has
no private dependency.

Peer-to-peer networking, STUN, TURN, ICE, direct terminal emulation, arbitrary
remote shell, and session-specific Durable Objects are deliberately deferred.
They are not prerequisites for hosted, self-hosted, or local control.
