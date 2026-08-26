# Design: Official Herdr Installer Execution

## Technical Approach

Replace only the metadata-gated Herdr path in `install.sh`. `install_herdr_runtime` will reuse an already executable `$HOME/.local/bin/herdr`; otherwise it will create a same-directory private mode-0700 temporary file, download the complete `https://herdr.dev/install.sh` with `curl`, execute that file with `HERDR_INSTALL_DIR=$HOME/.local/bin`, remove it on every exit path, and verify the executable. The official script remains the owner of latest-release selection and binary SHA-256 validation. `configure_terminal_dots` retains the atomic `none` prewrite and activates Herdr only after this contract and config preservation succeed.

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|---|---|---|---|
| Installer boundary | Download then execute the complete official script directly from a mode-0700 temp file | `curl | sh` or locally duplicated release metadata | Prevents partial streamed execution and avoids inventing drift-prone URLs, versions, or hashes. |
| Failure state | Keep `none` until executable verification and config preservation pass; reset to `none` on failure | Preserve a prior selection or fall back to TMUX | Fail-closed behavior prevents startup of an incomplete runtime and preserves exclusive selection. |
| Idempotence | Short-circuit before `curl` when the target is executable; copy config only when absent | Reinstall or overwrite user config | Reuses working software and maintains non-destructive user state. |

## Data Flow

```text
prompt → write none → install_herdr_runtime
       → curl complete script → execute with HERDR_INSTALL_DIR
       → verify executable → preserve config → write herdr
       ↘ any failure: cleanup temp → write none; never call TMUX
```

`install_herdr_runtime` owns temporary-file lifecycle. It must create the file beside the target binary under `umask 077`, explicitly enforce mode `0700`, and clean it after download failure, script failure, verification failure, or success. It must not invoke `herdr_release_metadata`, `sha256sum`, package removal, or any alternate runtime. `configure_terminal_dots` remains the only state transition coordinator; `write_terminal_state none` remains the failure reset.

## File Changes

| File | Action | Description |
|---|---|---|
| `install.sh` | Modify | Remove `herdr_release_metadata`; add official endpoint download, private temp cleanup, direct script execution, executable verification, and unchanged state/config/TMUX boundaries. |
| `tests/test_installer.sh` | Modify | Replace metadata/digest fixtures with hermetic curl and official-script fixtures; retain all existing state, opt-out, launcher, Zsh, Kitty, and TMUX coverage. |
| `README.md` | Modify | Document official-script provenance, its latest.json/SHA-256 responsibility, temp-file trust boundary, fail-closed behavior, and absence of streamed execution. |
| `openspec/changes/herdr-official-installer/specs/installer-terminal-selection/spec.md` | Modify | Delta already defines official-script success, failure, cleanup, reuse, and no-fallback scenarios; keep wording aligned with the implementation contracts. |

## Interfaces / Contracts

```bash
HERDR_INSTALLER_URL='https://herdr.dev/install.sh'
HERDR_BIN="$HOME/.local/bin/herdr"
install_herdr_runtime() -> 0 iff HERDR_BIN is executable after reuse or official execution
```

The curl seam must receive `--fail --location --silent --show-error --output TEMP HERDR_INSTALLER_URL`; TEMP is same-directory and mode `0700`. The execution seam must invoke `TEMP` as the downloaded executable with `HERDR_INSTALL_DIR="$HOME/.local/bin"`. A nonzero curl/script result or non-executable binary returns nonzero after cleanup. Existing executable content is unchanged and causes no curl/script invocation. `configure_terminal_dots` writes `herdr` only after `install_herdr_runtime` and `preserve_herdr_config`; failures write `none` and do not call `install_tmux_runtime`.

## Testing Strategy

Strict TDD RED tests use the existing sourced-function harness and isolated HOME/XDG/PATH fixtures. Fake `curl` records the exact endpoint/output and writes a complete fixture script; that script records `HERDR_INSTALL_DIR`, verifies its own `0700` mode, and optionally creates the binary. RED coverage must assert: outer download and script execution occur in order; curl failure skips execution; script failure and missing executable reset `none`; success removes the temp file and activates Herdr; existing executable skips both download and execution without changing content; every attempted temp file is absent afterward; and Herdr failure never invokes TMUX. Existing prompt, atomic-state, config-preservation, opt-out, no-TTY, Zsh, Kitty, and TMUX tests remain regression coverage. No E2E test is applicable.

## Threat Matrix

| Boundary | Applicability | Safe/failure behavior and planned RED test |
|---|---|---|
| Documentation-like paths | Applicable — `install.sh` is executable and the downloaded script is an execution boundary | Execute only the private downloaded temp file and repository `install.sh`; never source README/spec/config. RED: assert temp mode `0700`, target executable classification, and no README/spec execution. |
| Git repository selection | N/A — no `git -C`, repository selector, or VCS path is introduced | No behavior or RED test. |
| Commit state | N/A — installer does not stage, commit, or inspect index state | No behavior or RED test. |
| Push state | N/A — installer does not push or resolve refs | No behavior or RED test. |
| PR commands | N/A — no PR or VCS automation is involved | No behavior or RED test. |

## Migration / Rollout

No migration required. Existing binaries and user configuration remain intact; failure writes `none`. Rollback reverts only the four in-scope artifacts and restores the metadata blocker.

## Open Questions

None.
