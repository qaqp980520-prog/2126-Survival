# Mineral Grid Transaction Rollback Output Guard — M0.1.44

## Purpose

Close the final root-project Godot test step found by a second full-workflow audit after M0.1.43. The transactional rollback test already captured output and required its success marker, but it did not reject Godot runtime/parser diagnostics and had no explicit timeout. This left one remaining false-green gap in the root-project validation steps.

## Source and dependency

- Parent PR: #377 feature branch, through child PR #378.
- Branch: `ci/backrooms-core-test-output-guards-2026-11-16`.
- Prior exact HEAD with M0.1.43: `72a47390fc6450fa9b6902aca0c299f4e1cb23d1`.
- Godot version: 4.3.
- Existing test: `tests/mineral_grid_streaming_transaction_test.gd`.
- No production gameplay code, save schema, scenes, assets, input mappings, Project Settings, or third-party dependencies changed.

## Files

- `.github/workflows/godot-validation.yml`
  - Step: `Run mineral grid streaming transactional rollback tests`.
  - Command: `tests/mineral_grid_streaming_transaction_test.gd`.
- `docs/BACKROOMS_MINERAL_GRID_TRANSACTION_ROLLBACK_OUTPUT_GUARD_M0_1_44.md`
  - This version record.

## Change

The step now:

1. Runs with `timeout -k 5s 45s`.
2. Captures stdout and stderr together.
3. Fails on non-zero exit or timeout.
4. Rejects `SCRIPT ERROR`, `ERROR:`, and `FAIL:`.
5. Requires the exact success marker: `Mineral grid streaming transactional rollback tests passed.`.

## Validation status

- Static exact-replacement audit: pending final exact-head review.
- The previous M0.1.43 HEAD `72a47390fc6450fa9b6902aca0c299f4e1cb23d1` passed Full Gate #43855532023 (554/554 validation steps, 555/555 total job steps, 0 failures/skips, 19/19 associated workflows). That run validates the three M0.1.43 guards, not this M0.1.44 follow-up.
- New M0.1.44 exact-head Godot 4.3 Full Gate: pending.
- Full log diagnostic scan for the new exact HEAD: pending.
- Local Godot executable unavailable; engine validation runs through GitHub Actions.

## Import and test

- Import: `godot --headless --path . --editor --quit`.
- Focused test: invoked by the named workflow step in `.github/workflows/godot-validation.yml`.
- No third-party dependencies.

## Limitations and next steps

- The guard applies to the root 2126 Survival project test only; legacy standalone KROLL project test steps are outside this PR's scope.
- Run a new exact-head Full Gate, verify the transactional rollback step and all associated focused workflows, then scan the complete job log.
- Keep PR #378 Draft until the new exact-head gate and log scan pass.
- After independent review, merge only into PR #377's feature branch and rerun PR #377. Never merge directly to main.
