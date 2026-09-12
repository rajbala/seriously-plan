# North-star command-center scenario

Seriously exists first to answer, at a glance:

- Which coding agents are working, finished, blocked, or waiting for me?
- Which CI runs, pull-request reviews, and deployments have completed, and with
  what result?
- What token usage and estimated spend have I accumulated today?
- Which development and infrastructure machines are healthy?
- What changed recently, and what needs my attention now?

The reference user's sources are GitHub, Codex, Claude Code, Cloudflare, and
home-lab machines. This stack validates the product but does not define its
domain model. A GitLab, Forgejo, Jenkins, local-model, or other community
integration must be able to produce the same experience without forking core
widgets.

```text
┌───────────────────────────────────────────────────────────┐
│  AI COMMAND CENTER                          1:32 PM        │
│                                                           │
│  ● Claude       ● OpenAI       ● Home Lab       ● GitHub  │
├───────────────────────────────────────────────────────────┤
│ ACTIVE AGENTS                                             │
│ Claude Code     project-a      ● WORKING       18m        │
│   Implement billing parity                                │
│ Codex           project-b      ◉ NEEDS INPUT    7m        │
│   Structured response required                            │
├───────────────────────────────────────────────────────────┤
│ TODAY                                                     │
│ Claude     18.4M tokens     $22.81                        │
│ OpenAI      7.2M tokens     $11.42                        │
│ Total                       $34.23                         │
├───────────────────────────────────────────────────────────┤
│ INFRASTRUCTURE                                            │
│ Omarchy-1       ● Online       CPU 32%     RAM 18/32 GB   │
│ Mac mini        ● Online       iOS build running          │
├───────────────────────────────────────────────────────────┤
│ RECENT                                                    │
│ ✓ project-a tests passed                         1m ago    │
│ ✓ project-b PR review completed                  4m ago    │
│ ! project-b agent waiting for approval           6m ago    │
└───────────────────────────────────────────────────────────┘
```

## Composition, not plugin proliferation

The pipeline is `source → connector or collector → normalized records and
events → query → widget`. GitHub and GitLab connectors may both emit the same
change-request and check-run records. Codex, Claude Code, and future agent
collectors may all emit the same work-session and usage records. Generic active
work, attention, CI, review, usage, infrastructure, and recent-event widgets
query those records; they are not copied once per provider.

Extensions may contribute a connector, collector, genuinely new record schema,
normalizer, declarative widget, or capability-controlled action. Core owns the
small interoperable record vocabulary and versioned schemas:

- `WorkSession`: source, project, agent/model, summary, branch, start/update
  times, and `queued | working | needs_input | blocked | completed | failed |
  disconnected | unknown` state;
- `ChangeRequest`: repository, number, title, lifecycle, and review state;
- `CheckRun`: subject, queued/running/completed state, conclusion, and URL;
- `Deployment`: environment, revision, state, conclusion, and timestamps;
- `UsageAggregate`: source, model, time bucket, input/output/cache tokens, and
  centrally estimated cost;
- `HostObservation`: host, freshness, health, and typed resource measurements;
- `ActivityEvent`: immutable typed transition referencing its source record.

Every record carries source identity, observation time, freshness, and stable
external identity so updates deduplicate and stale observations cannot regress
newer state.

## Attention and evidence

Attention is a declarative, user-configurable projection, not connector-specific
UI logic. Initial rules include agent input required, failed CI, requested PR
changes, failed deployment, stale collector, offline host, and usage threshold.
Rules produce typed attention items with severity, subject, reason, timestamp,
and acknowledged/resolved lifecycle; connectors cannot inject executable rules.

Agent state must use the strongest structured evidence available: native event
or hook, official SDK/session API, versioned structured transcript metadata, or
an explicit collector state machine. Regex matching terminal prose, prompts, or
log strings is prohibited. If no supported structured signal proves a state, the
collector reports `unknown`, including `evidenceKind`, `observedAt`, and
`authoritative | inferred | unknown` confidence. The UI never presents an
inference as authoritative.

Prompt or conversation content is not collected or displayed by default. A
source may expose a separately consented, narrowly scoped content capability,
but status and attention features must work from structured metadata without it.

## End-to-end acceptance

The release scenario runs with GitHub, Codex, Claude Code, Cloudflare, and one
host collector, then substitutes at least one community connector producing the
same normalized records. On Node/SQLite and Workers/D1 it must demonstrate:

1. an agent moves from working to needs-input without parsing display text;
2. CI and review completion appear with correct status after webhook delivery
   and after missed-webhook polling reconciliation;
3. deployment and host-health changes enter the unified recent feed;
4. daily token totals and estimated spend reconcile across collectors;
5. attention items open, acknowledge, and resolve deterministically;
6. Wi-Fi loss, server restart, notification loss, and reconnect cause neither
   missed nor duplicated visible transitions; and
7. a display receives no provider credential or administrative capability.
