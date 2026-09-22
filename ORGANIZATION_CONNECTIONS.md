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

Administrators set visibility policy separately from display assignment. Policies
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
2. Verified member mapping and bounded synchronization with provenance.
3. Server-enforced audience policies and aggregate projections.
4. Admin display assignments and authorized combined dashboards.

Acceptance requires both SQLite and D1 tests for cross-organization and cross-user
refusal, duplicate IDs, personal-data isolation, aggregate-only disclosure, member
removal, display reassignment, active streams and exports, stale sessions and
backup restore. Verify no API tokens or forbidden individual fields reach displays.
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
