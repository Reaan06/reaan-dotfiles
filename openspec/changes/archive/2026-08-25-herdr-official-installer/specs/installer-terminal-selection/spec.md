# Delta for Installer Terminal Selection

## MODIFIED Requirements

### Requirement: Rename and gate terminal selection

The installer MUST be `install.sh`. It MUST gate terminal DOTS behind default-no, preserve the existing opt-out prompt behavior, then offer Herdr/TMUX with Herdr as the default.
(Previously: `install.sh` gated terminal DOTS behind default-no and offered Herdr/TMUX with Herdr default.)

#### Scenario: Decline terminal DOTS

- GIVEN `install.sh` is run on Arch
- WHEN terminal DOTS are declined or left at default
- THEN it MUST persist `none`, skip runtime choice, and preserve the declined flow

#### Scenario: Select a runtime

- GIVEN terminal DOTS are accepted
- WHEN the runtime prompt is blank or answered Herdr/TMUX
- THEN that value MUST be persisted, with blank meaning Herdr

### Requirement: Persist one exclusive and idempotent selection

The installer MUST persist exactly one of `none`, `herdr`, or `tmux` at `$XDG_CONFIG_HOME/reaan/terminal-dots.conf`. A Herdr selection MUST use the official installer endpoint `https://herdr.dev/install.sh` with `HERDR_INSTALL_DIR=$HOME/.local/bin` when no usable existing executable is available, and MUST activate only after the executable is available. Each run MUST converge idempotently: only the selected runtime is active, with no duplicate package/config/startup or user-config overwrite.
(Previously: Herdr activation was blocked on local release metadata rather than the official installer and executable check.)

#### Scenario: Rerun with an existing choice

- GIVEN a valid selection and existing user files
- WHEN the installer is rerun with the same or another valid choice
- THEN state and activation MUST remain singular without duplicates or destructive overwrites

#### Scenario: Successful official Herdr installation

- GIVEN terminal DOTS are accepted, Herdr is selected, and no executable exists
- WHEN the official installer is fetched and completes successfully for `$HOME/.local/bin`
- THEN an executable `$HOME/.local/bin/herdr` MUST be verified before `herdr` is persisted or activated

#### Scenario: Reuse an existing Herdr executable

- GIVEN Herdr is selected and `$HOME/.local/bin/herdr` is already executable
- WHEN the installer runs
- THEN it MUST preserve the executable and converge without duplicate installation or activation

#### Scenario: Stale or invalid state

- GIVEN state is missing, malformed, or unsupported
- WHEN installation or startup evaluates it
- THEN it MUST mean `none` until a valid selection succeeds

### Requirement: Fail safely and preserve user state

A runtime MUST be enabled only after its requirements succeed. Herdr requires successful official-script download and execution plus a verified executable. Any failure MUST persist `none`, MUST NOT fall back to another runtime or invoke TMUX, and MUST NOT uninstall software or delete user configuration.
(Previously: Unsupported systems or Herdr/TMUX failure disabled startup without official-script and post-install executable requirements.)

#### Scenario: Runtime installation failure

- GIVEN Herdr download, execution, or verification fails, or TMUX cannot be installed
- WHEN the installer completes
- THEN it MUST report failure, disable startup, and MUST NOT activate a runtime partially

#### Scenario: Official installer download failure

- GIVEN Herdr is selected and `https://herdr.dev/install.sh` cannot be downloaded
- WHEN installation completes
- THEN it MUST persist `none`, skip execution, and MUST NOT invoke TMUX as a fallback

#### Scenario: Official installer failure

- GIVEN the official script is downloaded but does not complete successfully
- WHEN installation completes
- THEN it MUST persist `none` and MUST NOT activate Herdr or alter existing user configuration

#### Scenario: Missing executable after installer success

- GIVEN the official script completes but `$HOME/.local/bin/herdr` is not executable
- WHEN installation completes
- THEN it MUST persist `none` and MUST NOT activate Herdr or invoke TMUX

#### Scenario: Temporary script cleanup

- GIVEN the official script is downloaded for a Herdr attempt
- WHEN the attempt completes successfully or fails
- THEN the temporary script MUST be removed

#### Scenario: Opt out after prior installation

- GIVEN runtime packages or user configuration already exist
- WHEN terminal DOTS are declined later
- THEN `none` MUST disable startup while packages and user configuration stay intact
