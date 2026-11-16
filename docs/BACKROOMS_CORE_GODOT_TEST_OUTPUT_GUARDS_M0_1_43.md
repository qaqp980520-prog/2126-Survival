# Core Godot Test Output Guards — M0.1.43

## Purpose

Close three remaining unguarded root-project Godot test steps in the exact PR #377 validation workflow. Previously these tests relied only on Godot's process exit code; a runtime/parser diagnostic that does not produce a non-zero exit could be missed, repeating the false-green class already found in the Backrooms RNG audit.

## Source and dependency

- Parent: PR #377 exact HEAD `85f4605b8122570f9caade1d548d61b4fdf0a598`.
- Branch: `ci/backrooms-core-test-output-guards-2026-11-16`.
- Target: PR #377 feature branch `fix/backrooms-underground-surface-window-on-reconciled-runtime-2026-11-16`.
- Godot version: 4.3.
- No production gameplay code, save schema, scene, asset, input mapping, or project setting is changed.

## Files

- `.github/workflows/godot-validation.yml` — wrap three root-project test commands with captured output, a 45-second timeout, explicit rejection of `SCRIPT ERROR`, `ERROR:`, and `FAIL:`, and a required success marker:
  - `tests/inventory_save_validation.gd`
  - `tests/inventory_save_adapter.gd`
  - `tests/world_bridge_binding_test.gd`
- `docs/BACKROOMS_CORE_GODOT_TEST_OUTPUT_GUARDS_M0_1_43.md` — this version record.

## Validation contract

Each step now:
1. Runs under `timeout -k 5s 45s`.
2. Captures stdout and stderr together.
3. Fails on a non-zero exit or timeout.
4. Fails if the captured output contains `SCRIPT ERROR`, `ERROR:`, or `FAIL:`.
5. Requires the test-specific success banner.

Expected banners:
- `Inventory save validation smoke tests passed.`
- `Inventory save adapter tests passed.`
- `SurvivalWorldBridge binding tests passed.`

## Test status

- Static replacement audit: each of the three old raw commands matched exactly once and was replaced exactly once.
- Godot 4.3 execution: pending GitHub Actions on the PR's exact head; no pass is claimed in this version record until the new run completes.
- The existing PR #377 Full Gate passed before this child change; it is not evidence for this new head.

## Import and run

- Import: `godot --headless --path . --editor --quit`.
- Focused tests are invoked by the three named steps in `.github/workflows/godot-validation.yml`.
- No third-party dependencies.

## Limitations and next steps

- This change hardens the three remaining unguarded root-project test steps found in the workflow audit; it does not refactor the legacy standalone KROLL project test steps.
- M0.1.43 exact-head validation is complete on `72a47390fc6450fa9b6902aca0c299f4e1cb23d1`; the fourth remaining root-project gap is tracked separately in M0.1.44.
- Full Gate log #43855532023: 7,743,181 characters / 84,667 lines; zero `SCRIPT ERROR:`, `ERROR:`, or `FAIL:` diagnostic lines after excluding the CI's own shell guard commands.
- Keep this child PR Draft until exact-head validation passes; after independent review, merge only into PR #377's feature branch and rerun PR #377. Never merge directly to main.
