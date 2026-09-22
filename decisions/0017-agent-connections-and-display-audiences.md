# ADR 0017: Separate agent connections from display audiences

Status: accepted direction; organization implementation deferred.

## Context

A launcher-only collector with daily credential replacement does not satisfy
ordinary desktop or CLI usage. Organizations also need administrator-configured
collection without requiring each developer to install a hook. Collection access
must not grant every member or display access to individual activity.

## Decision

Adopt personal native-plugin connections and organization server-side API
connections as distinct first-class paths. Keep optional managed endpoint telemetry
separate. Define visibility policies, dashboard audience scopes and display
assignments independently from provider enrollment. Enforce all disclosure on the
server. See [the specification](../ORGANIZATION_CONNECTIONS.md).

## Alternatives and consequences

Reject a mandatory wrapper launcher, blanket organization-wide member visibility,
and client-only widget hiding. A universal server API for every personal account
is not an assumed capability. Provider/account capability validation and freshness
labels are required. Personal data is not shared by organization membership alone.
Combined views require explicit permissions and provenance-aware deduplication.
This refines ADR 0008 without replacing the normalized collector/provider boundary;
ADR 0009 hosted tenant isolation remains intact. Individual plugin installation is
current scope; this decision alone starts no organization implementation.
