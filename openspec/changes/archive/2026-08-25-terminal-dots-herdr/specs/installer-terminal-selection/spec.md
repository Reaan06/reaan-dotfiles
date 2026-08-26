# Installer Terminal Selection Specification

## Purpose

Define terminal selection.

## Requirements

### Requirement: Rename and gate terminal selection

The installer MUST be `install.sh`. It MUST gate terminal DOTS behind default-no, then offer Herdr/TMUX with Herdr default.

#### Scenario: Decline terminal DOTS

- GIVEN `install.sh` is run on Arch
- WHEN terminal DOTS are declined or left at default
- THEN it MUST persist `none`, skip runtime choice, and preserve the declined flow

#### Scenario: Select a runtime

- GIVEN terminal DOTS are accepted
- WHEN the runtime prompt is blank or answered Herdr/TMUX
- THEN that value MUST be persisted, with blank meaning Herdr

### Requirement: Persist one exclusive and idempotent selection

The installer MUST persist exactly one of `none`, `herdr`, or `tmux` at `$XDG_CONFIG_HOME/reaan/terminal-dots.conf`. Each run MUST converge idempotently: only the selected runtime is active, with no duplicate package/config/startup or user-config overwrite.

#### Scenario: Rerun with an existing choice

- GIVEN a valid selection and existing user files
- WHEN the installer is rerun with the same or another valid choice
- THEN state and activation MUST remain singular without duplicates or destructive overwrites

#### Scenario: Stale or invalid state

- GIVEN state is missing, malformed, or unsupported
- WHEN installation or startup evaluates it
- THEN it MUST mean `none` until a valid selection succeeds

### Requirement: Fail safely and preserve user state

A runtime MUST be enabled only after requirements succeed. Unsupported systems or Herdr/TMUX failure MUST disable startup; software MUST NOT be uninstalled or user configuration deleted.

#### Scenario: Runtime installation failure

- GIVEN Herdr cannot be downloaded/verified or TMUX cannot be installed
- WHEN the installer completes
- THEN it MUST report failure, disable startup, and MUST NOT activate it partially

#### Scenario: Opt out after prior installation

- GIVEN runtime packages or user configuration already exist
- WHEN terminal DOTS are declined later
- THEN `none` MUST disable startup while packages and user configuration stay intact
