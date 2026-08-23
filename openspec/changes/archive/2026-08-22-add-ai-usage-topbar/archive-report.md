# Archive Report: add-ai-usage-topbar

## Final State

- Status: `success` with non-critical warnings.
- Artifact store: hybrid (OpenSpec filesystem plus Engram).
- Verification verdict: `pass_with_warnings`.
- Evidence revision: `sha256:28de9d1ffd952f97bd2a5bc4e1e2b5111412e47f1b2bf75c5604acd499201891`.
- Requirements: 6/6; scenarios: 6/6; tasks: 9/9; blockers: 0; critical findings: 0.
- No application source, tracking files/contracts, provider quotas, network, credentials, prompts/raw messages, or unrelated worktree changes were modified by archival.

## Source Artifacts Read

OpenSpec artifacts:

- `/home/reaan/reaandots/openspec/changes/add-ai-usage-topbar/proposal.md`
- `/home/reaan/reaandots/openspec/changes/add-ai-usage-topbar/specs/ai-usage-analytics/spec.md`
- `/home/reaan/reaandots/openspec/changes/add-ai-usage-topbar/design.md`
- `/home/reaan/reaandots/openspec/changes/add-ai-usage-topbar/tasks.md`
- `/home/reaan/reaandots/openspec/changes/add-ai-usage-topbar/verify-report.md`
- `/home/reaan/reaandots/openspec/config.yaml`

Engram artifacts read:

- `sdd/add-ai-usage-topbar/proposal` — observation `#597`
- `sdd/add-ai-usage-topbar/spec` — observation `#600`
- `sdd/add-ai-usage-topbar/design` — observation `#603`
- `sdd/add-ai-usage-topbar/tasks` — observation `#609` (reconciled, 9/9 complete, feature-branch-chain)
- `sdd/add-ai-usage-topbar/apply-progress` — observation `#611`
- `sdd/add-ai-usage-topbar/verify-report` — observation `#620`

No native review receipt was present in structured status; no review topics were read or required.

## Spec Sync

The delta is a complete new capability spec because no main spec existed. It was mechanically copied to:

- `/home/reaan/reaandots/openspec/specs/ai-usage-analytics/spec.md`

Mechanical copy readback (`diff -r`): empty output (no differences).

## Archive Move

The complete change folder was mechanically moved from:

- `/home/reaan/reaandots/openspec/changes/add-ai-usage-topbar`

to:

- `/home/reaan/reaandots/openspec/changes/archive/2026-08-22-add-ai-usage-topbar`

The active source directory is absent. The archived tree contains proposal, exploration, spec, design, tasks, and verify report artifacts. Mechanical move readback (`diff -r` against the pre-move recursive snapshot): empty output (no differences).

## Final Warnings

1. Graphical behavior remains unverified: Wayland, Hyprland, and Quickshell were unavailable, so no live graphical pass is claimed.
2. `tests/test_ai_usage.sh` contains a weak immediate re-hash assertion; independent HEAD comparison and final diff verification compensated, but the assertion should be strengthened in a later maintenance change.

These warnings are non-critical; no source fixes were made after the verify report.

## Engram Persistence

This report is persisted under topic key `sdd/add-ai-usage-topbar/archive-report` with `capture_prompt: false`.
