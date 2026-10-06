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
- estimated spend by provider/model and the versioned price snapshot used;
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

Activity-only hooks do not establish token usage. Before implementing a usage
adapter, record the supported structured source, its documented fields and
units, client coverage, required consent, and limitations. Supported provider
APIs, SDKs, native structured usage events, or separately consented structured
usage metadata may supply usage. Terminal scraping, interpreting prose, reading
conversation bodies, and estimating tokens from prompt length are prohibited.
An adapter that reads structured usage metadata must filter locally and transmit
only the approved usage fields; access to conversation content is not implied.

Each observation identifies its authenticated personal source, stable usage
identity, observation/usage period, provider/model, metric semantics, and evidence
kind. Distinguish measured tokens, provider-reported totals, locally reported
usage, and estimated monetary cost. A provider's billing total is not necessarily
identical to the client's reported usage; do not silently combine them.

Setup states which metrics the selected client/source can actually report.
Unsupported token metrics remain unavailable, not zero. Activity collection may
continue without usage collection, with that limitation visible. A provider API
that offers only account-level totals is shown as account-level usage and cannot
be advertised as repository analytics. Credential import is not evidence that
usage is being received. Combined views label partial coverage explicitly; a
subtotal from supported sources is not presented as complete account usage.

## Repository attribution

Repository naming is optional, explicit personal enrollment/configuration,
separate from permission to report activity or token totals. Preview the metadata
before enabling it. Never transmit absolute local paths, source contents,
prompts, provider credentials, or credential-bearing Git remote URLs.

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

Queries use the existing authenticated account and dashboard authorization
boundaries. An individual can see their own analytics; another user or display
receives it only through explicit authorized sharing. Installing or enrolling a
collector does not grant analytics read access. Repository labels and breakdowns
are personal data; public leaderboard payloads retain their existing exclusions.

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

A user can export retained usage, repository attribution, and activity metadata
through the existing authenticated export facilities. Deleting an observation,
repository attribution, or personal analytics removes or recomputes affected
aggregates as appropriate; deleting an attribution preserves the usage as
unattributed. Existing backup/restore and hosted deletion policies still apply.
Disconnecting a collector stops future collection but does not silently delete
previous history. Explain the distinction and provide an explicit deletion action.

## Acceptance gates

Before this feature is called complete, the same SQLite/D1 contract and browser
journeys must establish:

1. A supported usage source produces measured token totals, repository breakdowns,
   and daily/weekly/monthly views without transmitting forbidden content. An
   activity-only source visibly reports token usage as unavailable.
2. Input/output/cache categories follow the provider's documented semantics;
   missing cache fields are not invented. Cost uses a known price version or is
   explicitly unavailable, and estimated cost is never called an invoice amount.
3. Repository A, repository B, and unattributed observations reconcile to the
   personal total. Renames, forks, different hosts, multi-repository sessions,
   and explicit attribution changes preserve the correct historical allocation.
4. Duplicate submissions, concurrent ingestion, cumulative checkpoints,
   out-of-order updates, late delivery, and supported corrections produce the
   same totals and do not duplicate or erase history. Ambiguous source overlap
   is disclosed and excluded from a combined total.
5. Time-zone changes, midnight boundaries, daylight-saving transitions, and
   coarse provider periods preserve totals without guessed allocations.
6. Retention and storage limits bound detailed and aggregate storage; transport
   compaction leaves retained analytics intact. Aggregate-only periods, expired
   correction evidence, deletion, export, backup, and restore behave as documented.
7. A second user, collector credential, unassigned display, and hosted tenant
   cannot read another user's repository names or analytics. No public report
   contains personal repository identifiers.
8. Upgrading from every supported schema preserves existing activity, usage,
   credentials, and unrelated data. Records lacking repository evidence remain
   unattributed. Already discarded observations are not claimed as backfilled.

Implementation begins with a documented source-capability assessment and one
complete personal usage-to-repository vertical slice. Coverage for additional
clients/providers follows the same normalized contracts. Neither a fake token
fixture nor a working activity hook alone satisfies the real-source acceptance
requirement.
