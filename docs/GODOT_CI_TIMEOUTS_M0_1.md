# Godot CI timeout/concurrency hardening M0.1 — 2026-10-26

## Why

During the save-adapter bridge work, early test drafts could remain in a headless process after an assertion stopped the test function. Several old workflow runs stayed in progress. The test itself was corrected with explicit PASS/FAIL reporting and a watchdog; this workflow change prevents future runs from occupying a runner indefinitely and cancels superseded runs for the same PR.

## Changes

- Set a 15-minute job timeout for the Godot 4.3 validation job.
- Add a concurrency group keyed by pull-request number (or ref) with cancel-in-progress enabled.
- Keep all existing import, rules, runtime smoke, portal, inventory, and world-bridge integration steps.

## Validation

- This is a workflow-only change; the full test suite passed on the preceding code run #24 and documentation run #25.
- The workflow PR still needs its own CI run before merging.
- The old runs #20–#23 were created before the concurrency group existed, so the new setting cannot retroactively cancel those runs.

## Limitations

The 15-minute timeout bounds the job but does not replace test-level watchdogs. Future tests should always exit non-zero on failure and avoid assertion-only paths that can leave SceneTree running.
