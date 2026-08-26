# Archive Report: `herdr-official-installer`

## Final State

- Archive status: complete.
- Tasks: 11/11 complete; the persisted tasks artifact contains no unchecked implementation tasks.
- Verification: PASS; 3/3 requirements and 12/12 scenarios compliant, zero blockers, zero critical findings.
- Evidence revision: `sha256:87006b485248b43bca9e7a601e6a1f3297df86fbd9f0d7219e0645685a1c1f91`.
- Focused installer coverage: 14 scenario groups passed.
- Required project runner and full shell suite passed; no live network, Arch installation, Herdr session, or TMUX session was run.

## Specs and Archive

- Merged the three modified requirements from the delta into `openspec/specs/installer-terminal-selection/spec.md`, preserving the existing specification preamble and all unaffected requirement/scenario content.
- Did not modify `openspec/specs/terminal-session-integration/spec.md`.
- Moved the complete change folder to `openspec/changes/archive/2026-08-25-herdr-official-installer/`.
- Archived artifacts include proposal, exploration, delta specs, design, tasks, verify report, and this archive report.

## Engram Lineage

Observation IDs read for this archive:

- `#989` — `sdd/herdr-official-installer/proposal`
- `#994` — `sdd/herdr-official-installer/spec`
- `#998` — `sdd/herdr-official-installer/design`
- `#1001` — `sdd/herdr-official-installer/tasks`
- `#1002` — `sdd/herdr-official-installer/apply-progress`
- `#1006` — `sdd/herdr-official-installer/verify-report`

No review artifacts were read because the authoritative status had no `reviewGate`; no review was discovered for this candidate.

## Resolved Operational Note

The native settle initially reported a transient `no space left on device` lock-write error. The same idempotent settle request subsequently succeeded; this is resolved and is not an implementation failure.

## Risks and Limitations

- The installer executes user-supplied remote shell content from `https://herdr.dev/install.sh`; the downloaded script is staged privately and executed only after complete download, but the remote-shell trust boundary remains.
- Release selection and SHA-256 metadata remain mutable through the official endpoint's latest metadata.
- Hermetic fixtures do not validate live endpoint behavior, Arch package state, or a real Herdr/TMUX session.

## Mechanical Readback Evidence

Spec-sync `diff -r` output: empty (no differences).

Archive-move `diff -r` output: empty (no differences).
