# Organization connections and display audiences

Status: accepted product direction; implementation deferred. The current work
focuses on installing individual-account hooks through inspectable native agent
plugins, without a replacement launcher or daily manual credential renewal.
This document does not authorize organization API implementation or provisioning.

## Connection model

Separate collection, authorization, dashboard scope, and display assignment.

- Personal accounts connect a supported agent plugin once per execution
  environment; report only allowlisted activity metadata. User-authorized
  revocable enrollment must not require a daily replacement download.
- Organizations connect a provider organization/workspace API once through an
  administrator. Ordinary developers need no local installation for API-supplied
  data. Discover subscription, permission, client coverage and latency before
  enabling features; API availability is not universal personal-account access.
- Optional IT-managed endpoint telemetry can supplement unavailable live events.
  It requires an explicit organization rollout and is never a hidden prerequisite
  of the server-only connection. No replacement agent launcher is required.

Provider adapters retain fixed outbound destinations, encrypted server-side
credentials, bounded pagination and retries, durable checkpoints, revocation,
and SQLite/D1 parity. Displays never receive provider credentials. Scope every
provider identity by provider and workspace, not by email or display name alone.
Verify identity links; never silently associate personal and workplace accounts.

## Audiences and administration

A dashboard has an explicit data scope: personal activity, one member's activity
within an organization, team aggregates, organization aggregates, or a composition
of separately authorized personal and organization widgets. Provider workspace
identity is distinct from Seriously installation/hosted-tenant identity. A combined
view is not a cross-tenant query permission and must not bypass the existing
public/private repository boundary or hosted tenant isolation.

Only installation owners (or the selected hosted tenant's owners) may change
visibility policy through `audience.policy.manage`, consistent with the existing
settings privilege. Owners and admins may use `display.assignment.manage` to
assign an already permitted dashboard, never to widen policy. The standalone and
hosted role matrices in [Architecture](ARCHITECTURE.md) define these grants;
member, viewer, display and collector principals cannot mutate either policy.
Policies
can allow own details only, own details plus organization totals, team totals, or
explicitly authorized identifiable member breakdowns. Aggregate permission does
not imply access to underlying member records. Personal activity is private unless
explicitly shared; joining an organization does not import personal history.

Administrators assign approved dashboards to display clients. Each display gets a
separate revocable authorization bounded by its assignment and disclosure policy;
it never inherits the enrolling administrator's privileges. A shared lobby screen
is a separate audience from an authenticated member browser. Changing assignment,
removing membership, or reducing policy revokes incompatible cached, streamed,
export and API access under the established revocation bound.

The server checks permissions and computes authorized aggregates before returning
data. Widget selection is not an authorization boundary. The client receives the
permitted audience label (personal/member/team/organization/combined), source,
coverage and freshness needed to explain what it displays. Restricted fields are
not shipped and hidden in the UI. Aggregation policy must address small groups,
filter differencing and historical membership; implementation must define and test
its disclosure threshold before organization aggregates are enabled.

### Team identity and membership

Team totals remain disabled until an adapter supplies a stable team identifier
scoped by provider/workspace and an authoritative, versioned member set. Never
infer teams from names, email domains, dashboard selections or hook payloads.
Unsupported provider team APIs mean unsupported team totals; manual team creation
is a separate design. A complete bounded sync stages membership pages and commits
one snapshot, its authorization generation and source freshness deadline atomically.
Partial/error responses never add grants or mark an old snapshot fresh. Expired
membership denies team access until a successful sync. Known removals/reassignments
advance the generation immediately; already-authorized jobs and requests recheck
it before publishing. Revoking the workspace connection denies all its teams.

Multi-team members require authorization for each selected team. A union counts a
verified person once and cannot reveal unselected teams. Do not retrospectively
attribute events to today's team: use verified membership effective at event time
and current audience permission; unknown historical membership is excluded.

### Offline display disclosure

Protected organization/member/team content is memory-only on managed clients:
no service-worker, HTTP, Web Storage, IndexedDB or on-disk snapshot cache. Use
no-store responses. A server-authorized view lease lasts at most five seconds,
renewed only after fresh authorization; an open socket alone does not renew it.
Clients blank protected content at expiry, on disconnect, on page hide/suspend,
and before resume or history restoration until a fresh authorized response arrives.
An offline reload starts blank. Clock rollback never extends a monotonic lease.
This bounds cooperative application display/cache retention; it cannot revoke
screenshots or data deliberately copied by an authorized viewer.

## Data meaning

Activity, usage and live attention are distinct capabilities. Display API reports
as delayed aggregates when appropriate; never infer working/waiting/completed from
usage totals or missing events. Show unsupported, stale and disconnected states.
Retain source provenance and timestamps. Deduplicate API and hook observations only
with an established identity/event mapping; otherwise keep metrics separate and do
not sum overlapping usage. Permission to connect an API does not authorize retaining
prompts or transcripts; request minimum scopes and avoid content-bearing endpoints
unless separately designed and approved.

## Delivery and acceptance

Defer this phase until personal hook installation is usable. Then deliver:

1. Provider/account capability matrix and organization connection lifecycle.
2. Verified member and team mapping with bounded, versioned synchronization and provenance.
3. Server-enforced audience policies and aggregate projections.
4. Admin display assignments and authorized combined dashboards.

Public acceptance requires both SQLite and single-installation D1 tests for
isolation between provider workspaces connected to one installation, cross-user
refusal, duplicate provider/workspace/team/member IDs, personal-data isolation,
aggregate-only disclosure, member removal, display reassignment, active streams,
exports, stale sessions and backup restore. These are provider-workspace tests,
not hosted tenant tests. Separately, private seriously-cloud Workers/D1 acceptance
must exercise two authenticated hosted tenants with identical resource IDs across
requests, jobs, streams, caches, exports and restores, under
[the repository boundary](REPOSITORY_BOUNDARIES.md). No public hosted tenancy model
or SQLite hosted-tenant adapter is introduced.

Test every role's allow/deny matrix for policy changes and assignments, including
an admin who can assign but cannot widen disclosure. Test multi-team membership,
reassignment, deletion, stale/partial syncs, duplicate IDs, historical membership,
revocation races and union deduplication. Test offline disconnect plus revocation,
lease expiry, suspend/resume, clock rollback, back/forward restoration and offline
reload; protected content must blank within the five-second lease and stay out of
persistent caches. Verify no API tokens or forbidden individual fields reach displays.
Inject prompt/transcript canaries into successful API responses and error envelopes;
assert absence from normalized records, raw-response storage, checkpoints, logs,
diagnostics, backups, exports and displays. Retain only allowlisted metadata,
including on retries, pagination failures and malformed responses.
Test provider pagination, throttling, stale data, subscription loss, credential
revocation and overlapping API/hook observations. Test aggregate inference limits.
Demonstrate an organization dashboard from API data with no workstation plugin,
and a personal dashboard from a native plugin with normal agent launch behavior.
No live cloud resources or third-party organization connections are provisioned
merely to validate the implementation.

## Provider references

These establish possible sources, not guaranteed coverage for every account:

- [Claude Code Analytics API](https://platform.claude.com/docs/en/manage-claude/claude-code-analytics-api)
- [Claude Enterprise Compliance coverage](https://platform.claude.com/docs/en/manage-claude/compliance-faq)
- [OpenAI workspace analytics](https://learn.chatgpt.com/docs/enterprise/analytics-api)
- [OpenAI compliance and audit events](https://learn.chatgpt.com/docs/enterprise/compliance-api)
- [Codex managed hooks](https://learn.chatgpt.com/docs/hooks)
