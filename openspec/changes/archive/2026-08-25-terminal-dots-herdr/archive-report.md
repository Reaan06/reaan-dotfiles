# Archive Report: terminal-dots-herdr

## Closure

- **Status**: success
- **Artifact store**: hybrid (OpenSpec filesystem plus Engram progress/artifacts)
- **Archived**: 2026-08-25
- **Final verification**: PASS; evidence revision `sha256:8ae9bd96ebe0746b670b47690d2995de45382266946e603a5b175567b0a85022`
- **Requirements/scenarios**: 6/6 requirements and 12/12 scenarios
- **Tasks**: 10/10 complete; no unchecked implementation tasks
- **Blockers/critical findings/warnings**: 0/0/0

## Final-State Notes

The earlier verification coverage failure is historical only. A maintainer-authorized bounded correction added the two hermetic tests for later opt-out preservation and interactive TTY Zsh with `none`; fresh verification then passed. `tests/test_installer.sh` now contains 11 scenario groups. Focused, required, full shell, syntax, and boundary suites passed.

Herdr binary installation intentionally remains fail-closed because official Linux x86_64 URL/SHA-256 release metadata is unavailable. No real Herdr or TMUX session was launched, and no live runtime/network installation was attempted. Kitty remains the emulator, Zsh remains the shell, and the selected runtime remains exclusive.

## Specs Synced

- Created `openspec/specs/installer-terminal-selection/spec.md` from the complete delta spec.
- Created `openspec/specs/terminal-session-integration/spec.md` from the complete delta spec.
- No existing main specs were present; no existing requirements were removed or modified.

## Mechanical Readback Evidence

Both spec copies and the archive move were verified with `diff -r`; each produced empty output. The archive move snapshot contained the complete active change folder before the move. The archive report was added afterward and is therefore additive to that snapshot.

## Engram Observation Lineage

Full observations read before archival:

- `#937` — `sdd/terminal-dots-herdr/proposal`
- `#938` — `sdd/terminal-dots-herdr/spec`
- `#939` — `sdd/terminal-dots-herdr/design`
- `#941` — `sdd/terminal-dots-herdr/tasks`
- `#943` — `sdd/terminal-dots-herdr/apply-progress`
- `#969` — `sdd/terminal-dots-herdr/verify-report`
- `#972` — historical verification coverage discovery
- `#976` — remediation coverage bugfix

## Archived Contents

The archived folder contains the proposal, exploration, both specs, design, checked tasks, final verify report, state, and this archive report. The active change directory no longer contains `terminal-dots-herdr`.
