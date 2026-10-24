# Personal analytics

Seriously must help an individual understand their coding-agent activity and
usage over time, including which repositories account for that usage. This is
part of the complete self-hosted product, not a hosted-only feature. The same
contracts and observable behavior apply to Node/SQLite and Workers/D1.

This document extends the existing `WorkSession`, `UsageAggregate`, and
`ActivityEvent` model in [the product scenario](PRODUCT_SCENARIO.md), the
[collector milestone](ROADMAP.md#phase-4--codex-and-claude-code-collectors), and
[public SDK contracts](SDK_ARCHITECTURE.md). Organization API ingestion and
organization-wide reporting are separate work; personal analytics does not wait
for them or implicitly share personal records with an organization.

## User-visible outcome

An authenticated user can select today, the last 7 or 30 days, or a custom date
range and see:

- input, output, cache-read, and cache-write tokens, with provider-defined cache
  semantics made explicit;
- estimated spend by provider/model and the versioned price snapshot used,
  selected by usage period as described under historical accounting;
- daily, weekly, and monthly trends;
- usage by repository, agent, model, and connection, with drill-down to a
  repository's contributing sessions and usage observations;
- observed sessions and activity transitions alongside usage, with evidence and
  freshness labels; and
- source coverage, missing metrics, delayed observations, retention boundaries,
  and unattributed usage.

Live session state, historical activity, and usage totals are separate views.
Ending a turn does not erase its history. An immutable activity transition can
say that a turn ended without claiming the task completed. Working-duration
estimates must describe their observed intervals and gaps; hook counts are not
prompt counts, task counts, token counts, or exact time spent working.

## Collection and evidence

Use existing collector enrollment, source identity, normalized records,
validation, ingestion, and database adapters. Do not introduce a second collector
protocol, provider-specific dashboard, or parallel analytics event model.

Personal ingestion requires a server-recorded, immutable credential binding to
installation/tenant, personal subject, source, allowed record kinds, and the
user's repository-attribution setting. The
subject is the authenticated enrolling user, never a user ID asserted by the
collector payload. Existing unbound installation collectors cannot populate a
member's personal history; require explicit personal re-enrollment. Rotation
preserves the subject and revocation prevents further writes.

The named `manage_own_personal_collectors` capability lets each active user,
including members and viewers, enroll and revoke only their own personal sources.
It does not grant integration administration or management of other collectors.
An administrator cannot enroll a personal source as another user. In hosted
mode, the server verifies selected-organization membership and binds both that
tenant and the global user identity. One identity in two organizations has
separate credentials, histories, and queries; organization switching cannot
retarget a credential or merge history. Membership removal/suspension invalidates
access through the existing lifecycle checks. No organization role implicitly
grants access to another user's personal analytics.

Removal freezes the subject's personal history in that tenant: ingestion stops
and no organization role gains access. For 30 days the removed global identity
keeps only own-subject export and deletion for that tenant's history, through
the same capabilities and routes as an active user. After that window, or
immediately if the user deletes it, the history is retired with the same
tombstone and recomputation rules as whole-history deletion. Owners receive an
audited count of retired records, never their contents. Re-adding the identity
does not restore retired history.

Records written by an existing unbound installation collector before personal
analytics existed remain installation-scoped legacy records. They stay in a
labeled legacy view governed by the installation-level authorization that
already applied to them, and never appear in any member's personal history or
totals. A user may claim legacy records only through an explicit, audited
operation when server-recorded evidence shows that user enrolled the original
credential; without that evidence they stay legacy. Claiming moves them under
the user's personal subject and out of the legacy view.

Activity-only hooks do not establish token usage. Before implementing a usage
adapter, record the supported structured source, its documented fields and
units, client coverage, enrollment disclosures, and limitations. Supported
provider APIs, SDKs, native structured usage events, or supported structured
usage metadata may supply usage. Terminal scraping, interpreting prose, reading
conversation bodies, and estimating tokens from prompt length are prohibited.
An adapter that reads structured usage metadata must filter locally and transmit
only the approved usage fields; access to conversation content is not implied.

Each observation identifies its authenticated personal source, stable usage
identity, observation/usage period, provider/model, metric semantics, and evidence
kind. Distinguish measured tokens, provider-reported totals, locally reported
usage, and estimated monetary cost. A provider's billing total is not necessarily
identical to the client's reported usage; do not silently combine them.

Source periods are bounded. Ingestion rejects an observation whose period ends
more than 10 minutes after server receipt time, or whose span exceeds 31 days.
An open provider billing period is accepted only as a provider-reported total
whose start lies within the current documented billing cycle; its end is capped
at receipt time and it remains a replaceable checkpoint. Rejected observations
are counted on the source's coverage status with the reason; they are never
reassigned to arrival time or stored in future buckets. Operators may tighten
these limits.

Setup states which metrics the selected client/source can actually report.
Unsupported token metrics remain unavailable, not zero. Activity collection may
continue without usage collection, with that limitation visible. A provider API
that offers only account-level totals is shown as account-level usage and cannot
be advertised as repository analytics. Credential import is not evidence that
usage is being received. Combined views label partial coverage explicitly; a
subtotal from supported sources is not presented as complete account usage.

## Repository attribution

Installing and connecting the Seriously plugin is the consent to collect the
user's documented personal activity, usage, and repository metadata. Do not add
a separate token-collection opt-in or repeated permission prompts. Explain the
collected fields and source coverage in the existing installation/connection
flow; bundle any required telemetry forwarder with the plugin so users keep
launching their clients normally. Enrollment still selects the authenticated
personal subject and destination and does not authorize conversation contents.

Repository naming is optional configuration in that same flow, not a separate
consent step. Show the configured repository identity so attribution is clear.
When the user disables repository attribution, the setting is bound to the
credential, not only to the local preview. The collector omits repository fields
locally, and the server strips repository identifiers from every record kind,
including `WorkSession` project metadata, before storage. A later change to the
setting applies to future records only; it never relabels stored usage.
Never transmit absolute local paths, source contents, prompts, provider
credentials, or credential-bearing Git remote URLs.

Use the existing normalized source/session identity and validated repository
metadata. A hosted repository is identified by host and stable provider identity
where available, with its display name kept separately so renames do not create
new history. A local-only repository may use an explicit opaque identity and a
user-chosen label. Repository attribution must work without a GitHub connection.
Folder basenames, remote ordering, and current working directory alone do not
prove repository identity. No agent-side arbitrary filesystem exploration is
required to discover repositories.

Bind an attribution to the session or usage period it actually describes.
Changing a session's repository does not relabel previously accepted usage.
Linking a local identity to a hosted repository is an explicit, reviewable change;
reassigning old usage likewise requires an explicit correction. Preserve the
original evidence and do not silently merge unrelated repositories with matching
names, forks, or repositories on different hosts.

Usage spanning multiple repositories is split only when structured evidence
establishes the allocation. Otherwise it remains unattributed; never charge the
whole observation to every repository or divide it evenly by guesswork. Missing
or disabled attribution appears in an **Unattributed** bucket. Repository totals
plus unattributed totals reconcile to the same eligible personal usage total.

## Historical accounting

Preserve activity transitions and usage observations under the configured
retention policy. The display reconnect/change-event log is not the analytics
archive: compacting transport replay must not silently destroy retained usage or
its aggregates. Reuse existing SQL records, transactions, and migration paths.

Retries, reconnect replay, overlapping client sources, and provider polling must
not double-count a logical usage observation. Define source precedence and stable
identity before combining sources. Where overlap cannot be resolved, show the
sources separately and exclude the ambiguous overlap from a combined total.
Cumulative session counters are replacements/checkpoints, not additive deltas;
corrections update their contribution transactionally. Replaying an older
checkpoint cannot regress the accepted total. Gaps and source resets remain
visible rather than producing fabricated continuity.

Use canonical UTC half-open time intervals, projected into the user's chosen
IANA time zone for day/week/month views. Define weeks as Monday through Sunday.
Account for daylight-saving changes. Assign usage to its supported source period,
not its arrival time. A source total spanning several buckets without finer
timestamps is shown at its available granularity; do not manufacture a daily
allocation. Supported late observations and corrections update affected retained
buckets without counting them again in the arrival period.

Price snapshots are effective-dated. Each contribution's estimated cost uses the
catalog version effective for its usage period, not the version current at
ingestion or recomputation, and stores the selected version with the
contribution. A coarse period that crosses a price change shows its cost as
unavailable unless the source supplies finer timestamps to split it.

A custom range that starts or ends inside a retained bucket uses finer records
when they exist. When only the aggregate remains, the partial boundary bucket's
total is unavailable for that range; the view offers to expand the range to the
bucket boundaries. It never returns the whole bucket or a prorated share.

Queries use the existing authenticated account and dashboard authorization
boundaries. An individual can see their own analytics; another user or display
receives it only through a personal sharing grant. Installing or enrolling a
collector does not grant analytics read access. Dashboard access or display
assignment alone never selects a personal subject to query.

A personal sharing grant is created and owned by the subject. It names one
grantee user or display, the shared views and repositories, and an optional
expiry, and is audited. The subject can revoke it at any time. Revocation
advances the grant's generation, so in-flight reads authorized under the old
generation fail and subscribed displays stop receiving that subject's data.
Grants never extend to export or deletion.

Repository labels and breakdowns are personal data. Public leaderboard payloads
retain their existing exclusions, and the installation leaderboard publisher
excludes personal usage by default. A subject's usage is included only after
that subject opts in, separately from the operator enabling publication.
Withdrawing that opt-in or deleting the underlying history removes the
contribution from future reports and uses the existing report-deletion path to
remove it from retained and public data, including closed buckets.

## Retention, export, and deletion

Proposed first-release defaults are 90 days of detailed observations/transitions
and 365 days of daily usage aggregates. Operators can configure retention and
storage ceilings; setup and analytics show the effective policy. Aggregate
cardinality is also bounded, including repository, source, model, and time-bucket
dimensions. Limits and rejection behavior must be documented and tested; no
silent dropping or unbounded replacement of detailed events by aggregate rows.

Older aggregates may outlive detailed records. Such periods remain viewable but
are labeled as aggregate-only, with no promised session drill-down. Retain each
aggregate's bucket boundaries and granularity. After finer records expire, a
time-zone change cannot promise a new daily allocation that the retained buckets
cannot support; show that limitation rather than inventing one. Corrections
require the retained identity/contribution evidence needed to apply them safely;
if that evidence has expired, reject the correction explicitly rather than
incrementing an aggregate blindly. Never recreate expired history from a latest
session state.

The named `export_own_personal_analytics` capability is available to every
active user, including members and viewers, through
`GET /personal/analytics/export`. Reuse existing export serialization and
delivery, but bind its query to the authenticated personal subject and
installation/selected tenant. Client-supplied subject or tenant selectors cannot
widen that scope. Collector/display credentials cannot call it. This grants no
organization-wide export capability and never includes another user's records.

The named `delete_own_personal_analytics` capability is likewise available to
every active user and is bound the same way. It is distinct from organization
deletion and grants nothing beyond the caller's own subject. Its routes are:

- `DELETE /personal/analytics/observations/{id}` removes one observation;
- `DELETE /personal/analytics/attributions/{id}` removes one repository
  attribution and preserves the usage as unattributed; and
- `DELETE /personal/analytics` removes the whole personal history.

Each deletion removes or recomputes affected aggregates. Existing backup/restore
and hosted deletion policies still apply. Disconnecting a collector stops future
collection but does not silently delete previous history. Explain the
distinction and offer these explicit deletion actions.

Each subject has a monotonic personal deletion generation, advanced in the same
transaction that records a deletion. Every ingestion and recomputation
transaction captures that generation and its collection generation at
authorization and compares both at commit. A write authorized before a deletion
cannot commit after it, even if both authority checks were fresh.

Hosted personal deletion uses the existing external authority in
[ADR 0010](decisions/0010-external-key-and-audit-authority.md), not a new service.
Before deletion is acknowledged, finalize a non-rollbackable tombstone outside
the customer D1 backup lifecycle, scoped to tenant and personal subject plus one
selector:

- an observation selector: source/collector identity, collection generation,
  and the source-relative observation ID, so equal IDs from different sources
  never match;
- an attribution selector: the attributed session or usage period identity and
  the attribution version, which removes only the repository link; or
- a collection-generation selector for whole-history deletion.

Each tombstone also lists affected bucket identities. Store only deletion
selectors, not repository labels or usage content. Apply the existing
recoverable receipt protocol so an interrupted deletion remains denied until
reconciled.
Deleting all history retires its collection generation and credentials; explicit
re-enrollment permits new history without accepting replay from the retired one.

Hosted restore applies authoritative personal tombstones before reopening any
analytics reads, exports, ingestion, or aggregate publication. Remove deleted
contributions, reapply attribution tombstones so restored usage stays
unattributed, and recompute affected totals; a restored aggregate cannot bypass
this check even when its detailed rows have expired. If retained contribution
evidence cannot safely rebuild a bucket, invalidate it and show its total as
unavailable; never publish its pre-deletion value or a guessed replacement.
Retain the deletion evidence needed for every restorable snapshot. Current reads
and writes fail closed if fresh authority state is unavailable. Test restoring a
pre-deletion snapshot for observation, attribution, and whole-history deletion,
including replay and new collection afterward. This prevents
application-visible resurrection; it does not claim personal cryptographic
erasure of old tenant-encrypted backups.
Standalone restore retains its existing operator-controlled backup policy and
must disclose when restoring an older backup would reintroduce deleted history;
it does not depend on the private hosted authority.

## Acceptance gates

Phase 4 establishes the standalone portions below on Node/SQLite and
single-installation Workers/D1. Phase 5 adds the hosted tenant/global-identity
bindings and external-authority deletion/restore cases; those hosted requirements
do not block the standalone milestone. Both editions use the same personal
accounting contracts and corresponding browser journeys:

1. A supported usage source produces measured token totals, repository breakdowns,
   and daily/weekly/monthly views without transmitting forbidden content. An
   activity-only source visibly reports token usage as unavailable. With
   attribution disabled, a collector that still sends repository identifiers
   has them stripped before storage, and its usage appears as unattributed.
2. Input/output/cache categories follow the provider's documented semantics;
   missing cache fields are not invented. Cost uses the price version effective
   for the usage period, recomputation and late arrival select the same version,
   and a coarse period crossing a price change is explicitly unavailable.
   Estimated cost is never called an invoice amount.
3. Repository A, repository B, and unattributed observations reconcile to the
   personal total. Renames, forks, different hosts, multi-repository sessions,
   and explicit attribution changes preserve the correct historical allocation.
4. Duplicate submissions, concurrent ingestion, cumulative checkpoints,
   out-of-order updates, late delivery, and supported corrections produce the
   same totals and do not duplicate or erase history. Ambiguous source overlap
   is disclosed and excluded from a combined total.
5. Time-zone changes, midnight boundaries, daylight-saving transitions, and
   coarse provider periods preserve totals without guessed allocations. A
   custom range ending inside an aggregate-only bucket shows that boundary as
   unavailable. Future-dated and over-long periods are rejected and reported.
6. Retention and storage limits bound detailed and aggregate storage; transport
   compaction leaves retained analytics intact. Aggregate-only periods, expired
   correction evidence, deletion, export, backup, and restore behave as documented.
7. A second user, collector credential, and unassigned display cannot read or
   write another user's personal analytics, nor can an assigned display without
   a sharing grant or after its grant is revoked. Members/viewers can enroll
   their own sources and export or delete only their own records; administrator
   and payload subject substitution cannot impersonate another user. A deletion
   racing concurrent ingestion leaves no retired contribution behind. Phase 5
   additionally covers cross-tenant access, one global identity in multiple
   organizations, membership removal and its disposal window, and pre-deletion
   snapshot restoration for observation, attribution, and whole-history deletion
   under the external authority. No public report contains personal repository
   identifiers, and no leaderboard report includes a subject's usage without
   that subject's opt-in.
8. Upgrading from every supported schema preserves existing activity, usage,
   credentials, and unrelated data. Records lacking repository evidence remain
   unattributed. Already discarded observations are not claimed as backfilled.
   Legacy installation-scoped records stay out of personal views and totals,
   remain readable under their prior authorization, and move only through an
   evidence-backed claim.

Implementation begins with a documented source-capability assessment and one
complete personal usage-to-repository vertical slice. Coverage for additional
clients/providers follows the same normalized contracts. Neither a fake token
fixture nor a working activity hook alone satisfies the real-source acceptance
requirement.
