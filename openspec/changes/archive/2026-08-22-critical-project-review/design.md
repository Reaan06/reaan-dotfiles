# Design: Critical Project Review — Slice 1

## Technical Approach

Implement one contract-first boundary, not isolated patches. Runtime roots are derived from `QS_CONFIG_HOME` (default `${XDG_CONFIG_HOME:-$HOME/.config}`), `QS_RUNTIME_DIR` (default `${XDG_RUNTIME_DIR:-/tmp}`), and `QS_WALLPAPER_ROOT` (default `${XDG_PICTURES_DIR:-$HOME/Pictures}/wallpapers`). Thin Bash, Python, and QML adapters expose these names; tests may inject them for a relocated checkout and temporary HOME. QML passes values as `Process.command` arguments; helpers parse them and receive credentials only through stdin/file descriptors. Existing JSON, UI, and state-file contracts remain unchanged.

## Architecture Decisions

| Decision | Alternatives considered | Rationale |
|---|---|---|
| Environment-rooted path contract with language adapters | Repository-relative paths; per-component constants | Installed Quickshell runs from `$XDG_CONFIG_HOME`, while hermetic tests can inject a staged root without historical user paths. |
| Small boundary helpers, direct `Process` argv | Generic command-builder/state service; more `sh -c` wrappers | Keeps ownership explicit and removes data-derived shell source without introducing a new lifecycle or state system. |
| Credentials on stdin/FD; identifiers as discrete argv | Environment variables; token/password argv | Stdin/FD avoids argv and process-title disclosure; discrete argv preserves literal SSIDs, usernames, and app classes. |
| Approved wallpaper root is `~/Pictures/wallpapers` | Automatic fallback to `~/reaan-dotfiles/wallps` | The installer already copies source wallpapers there; refusing legacy fallback removes silent dependency and makes outside-path rejection testable. |

## Data Flow

```text
QML RuntimePaths ──→ Process argv ──→ Bash/Python adapter ──→ mocked/system command
       │                  │                 │                      │
       └── XDG roots ─────┴── stdin/FD ─────┴── JSON/stdout ────────┘
```

`RuntimePaths.qml` supplies script/config/runtime paths to `WifiGraph`, `GitHubManager`, `WallpaperPicker`, `AuraLauncher`, `DockManager`, `DockItem`, and fixed-path readers in `shell.qml`. `network-manager.sh`, `get-wifi-pass.sh`, `github-fetch.sh`, and new app/config adapters own parsing and subprocess invocation. Wallpaper bridge and apply script canonicalize with `realpath`, then require the resolved path to remain below `QS_WALLPAPER_ROOT` before reading or applying.

## File Changes

| File | Action | Description |
|---|---|---|
| `dot_config/scripts/runtime-paths.sh`, `runtime_paths.py` | Create | Shared environment contract adapters. |
| `dot_config/quickshell/components/RuntimePaths.qml` | Create | QML view of the same roots. |
| `dot_config/scripts/app-launch.py`, `github-config.py` | Create | Shell-free app dispatch/fallback and credential-file load/save/delete protocols. |
| `dot_config/scripts/{network-manager.sh,get-wifi-pass.sh,github-fetch.sh,pin_app.py,hide_app.py,wallpaper_bridge.py,apply-wallpaper.sh}` | Modify | Add stdin/argv contracts, path confinement, and fail-closed errors. |
| `dot_config/quickshell/{WifiGraph,GitHubManager,GitHubLinkingView,WallpaperPicker,AuraLauncher,DockManager,DockItem,shell}.qml` | Modify | Replace data-derived `sh -c`, hard-coded paths, and secret-bearing argv with direct commands and adapters. |
| `tests/test_quickshell_exec.sh`, `test_wifi_scan.sh`, `test_wallpaper_flow.sh`, `openspec/config.yaml` | Modify | Strict, fixture-backed runner and complete verification command. |
| `tests/test_slice1_boundaries.sh`, `tests/fixtures/` | Create | RED coverage, command doubles, temporary HOME, argv/stdin capture, and graphical evidence gate. |

`install-arch.sh` is compatibility-reviewed only: retain its active `DOTFILES_DIR` source and `~/Pictures/wallpapers` destination; installer redesign remains out of scope.

## Interfaces / Contracts

```text
network-manager.sh connect <ssid>       # password: stdin; never argv
get-wifi-pass.sh <ssid>                 # sudo password: stdin
github-fetch.sh <username>              # token: optional stdin
app-launch.py <exec-line>               # literal desktop metadata argv
pin_app.py <class> / hide_app.py <class> # literal class argv
wallpaper_bridge.py list|upload <path>  # upload path confined to approved root
```

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit | Root derivation, JSON, traversal/symlink rejection | Bash/Python fixtures under `set -euo pipefail`; exact stdout/stderr and nonzero assertions. |
| Integration | Missing/nonzero commands, metacharacters, secret-not-in-argv, valid behavior | PATH command doubles capture argv/stdin; no NetworkManager, GitHub, credentials, or destructive payloads. |
| Controlled graphical | Affected Quickshell process boundary | If Wayland/Hyprland/Quickshell is available, record runtime identity, boundary, and result; if unavailable, record `UNVERIFIED` and fail if availability is falsely claimed. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no documentation executable classification changes | None | None |
| Git repository selection | N/A — no Git repository selector or `git -C` behavior | None | None |
| Commit state | N/A — no commit automation | None | None |
| Push state | N/A — no push or refspec automation | None | None |
| PR commands | N/A — no PR automation or composed PR commands | None | None |

Process-specific RED tests remain mandatory: missing/nonzero helpers, shell metacharacters/newlines, traversal/absolute/symlink-outside paths, and fixture secrets absent from captured argv and shell source.

## Migration / Rollout

Deploy adapters first, then migrate callers, then enable the stricter test command. Existing config/runtime state files stay in their current locations. Users with legacy wallpapers must explicitly copy them into `~/Pictures/wallpapers`; there is no automatic legacy-path fallback. Tests snapshot `git status --porcelain`, use temporary HOME/XDG runtime roots, and never clean, reset, or write pre-existing `hyprland.conf`, `.atl/`, or OpenSpec changes. Rollback reverts only Slice 1 commits; restore the prior test command only for unrelated gating failures while preserving and reporting boundary failures.

## Open Questions

- [ ] Confirm the deployed Quickshell 0.3.0 stdin-writing API during apply; if unavailable, use an FD relay while preserving the same no-secret-in-argv contract.
