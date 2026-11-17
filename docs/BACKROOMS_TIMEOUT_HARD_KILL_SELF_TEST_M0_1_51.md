# M0.1.51 — GNU timeout hard-kill grace self-test

## Purpose

Prove that the GNU `timeout -k` behavior used by the root Godot validation commands actually escalates from SIGTERM to SIGKILL when a child process ignores SIGTERM. M0.1.50 statically audited the 117 root Godot test wrappers, but syntax inspection alone did not execute the timeout escalation path.

## GitHub delivery

- Repository: `qaqp980520-prog/2126-Survival`.
- Parent PR: #380 — Root Godot test hard-kill grace.
- Parent exact HEAD: `59d5975bc40363a28335a9a33fb9e71b21b6b2a4`.
- Branch: `ci/verify-timeout-hard-kill-grace-2026-11-17`.
- Workflow file: `.github/workflows/godot-validation.yml`.
- Version file: `docs/BACKROOMS_TIMEOUT_HARD_KILL_SELF_TEST_M0_1_51.md`.
- Workflow self-test commit: `e274d66f8b67c77087fb544c0ec81d9b390efcee`.

## Change

Add a shell-only self-test immediately before root-project Godot import:

- Start a child shell that explicitly ignores SIGTERM and remains active.
- Run it under `timeout -k 1s 1s`.
- Require exit status 137, proving the child was ultimately terminated by SIGKILL after the grace period.
- Capture output and fail closed on any unexpected exit status.
- Remove the temporary output file with an EXIT trap.

This validates the timeout mechanism itself; it does not replace the 117 per-test timeout guards or the Godot Full Compatibility Gate.

## Dependencies and import

- GNU coreutils `timeout` in the existing GitHub Actions container.
- Existing Godot 4.3 workflow; no new package or executable dependency.
- No project import change is required for the shell-only self-test.
- The normal root import remains `godot --headless --path . --editor --quit`.

## Validation status

- Local shell reproduction in the available Linux container: passed; the TERM-ignoring child produced exit status 137 after approximately 2 seconds.
- GitHub Actions exact-head Full Gate: pending for this PR; no CI pass is claimed at creation.
- The workflow step must pass on the exact PR head before this PR is considered validated.

## Scope and limitations

- No gameplay source, save schema, scenes, assets, Project Settings, input mappings, or third-party dependencies changed.
- No `daily_games/` files or commands changed.
- The test proves GNU `timeout -k` escalation for a direct child shell. It does not claim to validate every possible descendant process tree or host-level cancellation behavior.
- Local Godot executable remains unavailable; Godot engine validation runs in GitHub Actions.

## Next steps

1. Complete the exact-head Godot 4.3 Full Compatibility Gate and full-log scan.
2. Confirm the new self-test appears and passes before root import.
3. Obtain review.
4. Integrate only into PR #380's feature branch after review, then rerun #380 and its parent chain.
5. Never merge this stacked PR directly to main.
