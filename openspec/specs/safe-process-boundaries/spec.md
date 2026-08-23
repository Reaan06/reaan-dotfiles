# Safe Process Boundaries Specification

## Purpose

Ensure WiFi, GitHub, launcher, and pin/hide boundaries transport data without shell execution or argument credentials.

## Requirements

### Requirement: Non-interpolated untrusted values

The system MUST pass SSIDs, desktop metadata, application names, and paths as discrete arguments or controlled input, never interpolated into shell source.

#### Scenario: Shell metacharacters in data

- GIVEN an SSID, desktop entry, or application value contains separators, substitutions, or newlines
- WHEN the WiFi, launcher, GitHub, or pin/hide operation invokes a helper
- THEN the value is treated literally
- AND no additional command or redirection runs

### Requirement: Secret-free process arguments

Passwords, tokens, and equivalent credentials MUST NOT appear in `argv`, process titles, or shell source; they MUST use controlled standard input or a file descriptor when required.

#### Scenario: Credential capture check

- GIVEN a fixture password or token is supplied to an operation
- WHEN the child process is captured or inspected
- THEN the operation succeeds or reports its normal result
- AND the credential is absent from arguments and shell source

### Requirement: Preserve supported behavior

The system SHOULD preserve existing success, failure, and output contracts while enforcing these boundaries.

#### Scenario: Valid operation after hardening

- GIVEN valid WiFi, GitHub, launcher, or pin/hide input
- WHEN the operation runs through the hardened boundary
- THEN it produces the prior user-visible result or documented error
- AND it does not weaken the security constraints
