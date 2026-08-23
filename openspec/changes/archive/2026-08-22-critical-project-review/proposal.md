# Proposal: Critical Project Review — Slice 1

## Intent

Harden boundaries: make runtime paths portable, prevent data-derived shell execution and credential exposure, and make regressions fail closed. Path drift, interpolated `sh -c`, and the false-green execution test are evidence. Exploitability, fresh-install wallpaper behavior, and reload effects are hypotheses requiring controlled reproduction.

## Scope

### In Scope
- Define one portable path contract for helpers, QML, approved wallpaper inputs, and tests; remove user-specific absolute paths.
- Replace data-derived shell construction in WiFi, GitHub, launcher, and pin/hide flows with safe arguments, stdin, or file descriptors; keep secrets out of argv and shell source.
- Add hermetic fail-closed tests: strict shell settings, mocks, output/error assertions, metacharacter/traversal negatives, and secret-not-in-argv checks.
- Require a temporary-HOME fixture and controlled graphical-runtime verification for the affected Quickshell boundary.

### Out of Scope
- Installer redesign, privilege/dependency lifecycle, backups, transactions, and supply-chain policy.
- Process supervision, tracker consolidation, runtime ownership, and reconnect behavior.
- Wallpaper-engine selection/consolidation, documentation, and README convergence.

## Capabilities

### New Capabilities
- `portable-runtime-paths`: Portable repository, configuration, runtime, and wallpaper resolution.
- `safe-process-boundaries`: Untrusted values and credentials transported without shell interpolation or credential-bearing argv.
- `hermetic-regression-testing`: Deterministic boundary tests that fail closed.

### Modified Capabilities
- None — `openspec/specs/` has no existing capability specifications.

## Approach

Follow the contract-first slice. Reproduce the baseline on an unmodified reference where practical, write tests first under `strict_tdd`, centralize path resolution, and migrate named call sites. Preserve evidence versus hypotheses; use isolated fixtures, no real credentials, and no destructive payloads.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `dot_config/quickshell/`, `dot_config/scripts/` | Modified | Named Slice 1 boundaries. |
| `tests/`, temporary-HOME fixtures | Modified/New | Hermetic regression coverage. |
| `openspec/config.yaml` | Conditional | Expose the stricter gate if needed. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| QML/process compatibility or lost state | Med | Preserve interfaces; verify temporary layouts and graphical runtime. |
| Existing worktree changes are conflated | Med | Preserve the keyboard edit and pre-existing `.atl/`/`openspec/`; review Slice 1 only. |

## Rollback Plan

Revert Slice 1 commits, leaving pre-existing changes untouched. Restore the prior test command only if the stricter gate blocks unrelated behavior; retain failures and mark unsupported graphical scenarios unverified.

## Dependencies

- Controlled Wayland/Hyprland/Quickshell session; otherwise record graphical verification as unverified.

## Success Criteria

- [ ] No Slice 1 boundary depends on `/home/reaan/reaan-dotfiles` or interpolated secret/data shell source.
- [ ] Hermetic tests fail on missing commands, nonzero status, metacharacters, traversal, and secrets in argv.
- [ ] Temporary-HOME verification passes; graphical verification is evidenced or explicitly unverified.
- [ ] Installer, lifecycle, wallpaper-engine, and documentation follow-ups remain excluded.
