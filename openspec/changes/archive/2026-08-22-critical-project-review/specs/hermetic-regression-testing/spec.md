# Hermetic Regression Testing Specification

## Purpose

Provide deterministic evidence without real credentials, live services, or destructive payloads.

## Requirements

### Requirement: Fail-closed test execution

The regression suite MUST use strict shell failure handling, fail on missing/nonzero required commands, and assert expected output and errors.

#### Scenario: Missing or failing dependency

- GIVEN a required command is absent or returns nonzero
- WHEN the relevant test runs
- THEN the test exits nonzero
- AND it reports the failed boundary instead of passing

### Requirement: Negative security coverage

The suite MUST cover metacharacters, path traversal, rejected outside paths, nonzero helpers, and secrets-not-in-`argv` with isolated mocks.

#### Scenario: Malicious fixture inputs

- GIVEN metacharacter, traversal, and fixture-secret inputs
- WHEN boundary tests execute
- THEN traversal and unintended execution are rejected
- AND no fixture secret appears in captured arguments

### Requirement: Hermetic environment and runtime evidence gates

The suite MUST run with a temporary-HOME fixture and command doubles, preserve behavior/worktree changes, and exercise the affected Quickshell boundary in a controlled Wayland/Hyprland/Quickshell session when available. It MUST record the runtime identity, exercised boundary, and observable result. It MUST record graphical verification as `UNVERIFIED` only when that controlled runtime is unavailable.

#### Scenario: Isolated and unsupported runtime

- GIVEN a temporary HOME and no controlled graphical session
- WHEN the regression suite runs
- THEN filesystem and process assertions remain deterministic
- AND graphical verification is explicitly recorded as `UNVERIFIED`
- AND pre-existing `dot_config/hypr/hyprland.conf`, `.atl/`, and OpenSpec changes remain

#### Scenario: Controlled graphical runtime available

- GIVEN a temporary HOME and a controlled Wayland/Hyprland/Quickshell session is available
- WHEN the affected Quickshell boundary is exercised
- THEN evidence records the runtime identity, exercised boundary, and observable result
- AND graphical verification is not recorded as `UNVERIFIED`
