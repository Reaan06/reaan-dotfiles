# AI Usage Analytics Specification

## Purpose

Expose read-only local OpenCode token and cost analytics from the Quickshell top bar. Provider quotas, network access, credentials, multiple adapters, a daemon, persistent usage caching, keybinds, and application-time tracking are out of scope.

## Requirements

### Requirement: Discoverable monitor-aware access

The system MUST show a labeled AI Usage affordance in the top bar. Activating it MUST toggle a dedicated popup on the same monitor. The popup MUST follow existing monitor-aware anchoring, visibility, and dismissal behavior, and MUST show period totals, token categories, optional detail, source age/status, and manual refresh.

#### Scenario: Toggle on one monitor

- GIVEN a visible top bar on monitor A
- WHEN its AI Usage affordance is activated twice
- THEN the monitor-A popup opens and closes
- AND no duplicate popup remains on another monitor

### Requirement: Portable read-only adapter and JSON boundary

The adapter MUST resolve OpenCode data through `XDG_DATA_HOME`, defaulting to the user data directory when unset, and MUST open SQLite read-only without the SQLite CLI, network, credentials, or a persistent cache. It MUST emit JSON containing `status`, `generated_at`, `period`, and `totals`; `totals` MUST be an object for `ok` and null otherwise. An `ok` object MUST contain numeric `cost`, `input_tokens`, `output_tokens`, `reasoning_tokens`, and `cache_tokens`. Optional `breakdown` and `error` fields MUST NOT make undocumented schema assumptions.

#### Scenario: Relocated fixture and schema incompatibility

- GIVEN temporary HOME/XDG data containing a valid or incompatible fixture
- WHEN collection runs
- THEN valid output has the required shape and leaves the source unchanged
- AND incompatible output is `schema-error` with null totals

### Requirement: Period aggregation and optional breakdown

The adapter MUST aggregate supported cost and input, output, reasoning, and cache counters for the requested period without double counting. Provider/model groups MAY be emitted from available safe metadata; absent or incomplete detail MUST omit groups without invalidating totals.

#### Scenario: Partial provider metadata

- GIVEN valid counters and incomplete provider/model metadata
- WHEN the period is collected
- THEN totals equal the supported counters
- AND unavailable groups are omitted rather than invented

### Requirement: Explicit freshness, retention, and refresh

The boundary and UI MUST distinguish `ok`, `missing`, `stale`, `locked`, `malformed`, and `schema-error`; missing or failed data MUST NOT appear as zero. After a successful snapshot, a failed refresh MUST retain last-known-good totals, show age and exact status, and support retry. The UI MUST support manual refresh and bounded polling without overlapping uncontrolled requests or implying quota accuracy.

#### Scenario: Failure during live refresh

- GIVEN a retained successful snapshot and a missing, stale, locked, malformed, or incompatible source
- WHEN polling or manual refresh receives the failure
- THEN the snapshot remains visible with its age and exact status
- AND the next collection remains manually or boundedly retryable

### Requirement: Privacy and safe process boundaries

The feature MUST read and expose only normalized aggregates and approved provider/model metadata. It MUST NOT read prompts, raw messages, credentials, auth material, or application-time records. Paths MUST be discrete process arguments, never shell source, and secrets MUST NOT enter `argv`.

#### Scenario: Secret-bearing privacy fixture

- GIVEN fixture fields containing prompt-like text, raw messages, and secret markers
- WHEN adapter and process-boundary tests run
- THEN those values are absent from output, shell source, and arguments
- AND application-time tracking behavior remains unchanged

### Requirement: Hermetic regression evidence

Tests MUST use temporary XDG/HOME fixtures and isolated doubles to cover aggregation, JSON shape, all six statuses, retention, privacy, process boundaries, and no-regression behavior. Tests MUST fail on missing required commands or unexpected results and MUST NOT require a live service, credential, or real user database.

#### Scenario: Deterministic failure matrix

- GIVEN absent, stale, locked, malformed, and schema-incompatible fixtures
- WHEN strict fixture tests execute
- THEN each produces its documented status and assertion result
- AND the existing worktree and application-time tests remain preserved
