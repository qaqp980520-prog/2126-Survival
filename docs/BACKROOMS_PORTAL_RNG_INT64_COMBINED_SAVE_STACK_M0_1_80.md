# M0.1.80 — Backrooms Portal RNG Signed-64 Boundary Guard on Combined Save Parent

## Purpose

Remove the inherited Godot 4.3 false-green in the combined SurfaceWorld + Backrooms save parent PR #347. The previous portal-director test exited successfully even though oversized signed-64-bit RNG strings emitted real Godot conversion errors. This correction validates the decimal string range before conversion and makes the CI step reject engine diagnostics.

## Source and target

- Target PR: #347 — `feat/backrooms-combined-save-envelope-2026-11-13`.
- Base before this change: `78561e5dbf0f8d14202e1c025eeb65f8fff45f4d`.
- Source implementation: validated PR #383, exact HEAD `b592a3ef547b2e05d2c742893a3f25f46066e9a6`.
- PR #383 is a corrective source branch based on legacy PR #339; this is a selective file-level backport only. No divergent branch history is merged.
- Related child PR #348 already contains the canonical parser and signed-64-bit boundary tests; this update brings the parent branch into alignment.

## Root cause

The old parser called `int(saved_rng_state)` after `String.is_valid_int()`. Godot 4.3 accepts the lexical form of oversized decimal strings as integer-like text, but conversion emits runtime `ERROR:` diagnostics for values outside signed 64-bit bounds. The test process still printed its success marker and exited zero, so the workflow reported a false green.

Historical evidence: Full Gate [#43372327505](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43372327505), job `131710737640`, contained two actual errors:
- `999999999999999999999999999999999999999999` is too large.
- `-999999999999999999999999999999999999999999` is too small.

## Implementation

- `systems/BackroomsPortalDirector.gd`
  - Require a String RNG state.
  - Validate canonical signed-64 decimal syntax and lexical bounds before calling `int()`.
  - Accept exact INT64_MAX and INT64_MIN.
  - Reject overflow, underflow, plus-prefixed, leading-zero, negative-zero, malformed, and non-string values without mutating the director.
- `tests/backrooms_portal_director_test.gd`
  - Add exact signed-64 boundary round-trips.
  - Add overflow/underflow boundary rejection.
  - Preserve atomic rejected-load assertions.
- `.github/workflows/godot-validation.yml`
  - Capture the portal-director test output.
  - Apply a 45-second timeout with 5-second hard-kill grace.
  - Fail on `SCRIPT ERROR`, `ERROR:`, or `FAIL:`.
  - Require the exact success marker.

## Dependencies and import

- Godot 4.3; no third-party dependencies.
- Existing Backrooms portal director, SurfaceWorld combined envelope, and portal director test.
- No scene, Project Settings, save schema, RNG algorithm, serialized field format, portal spawn policy, or gameplay behavior changes.
- Import: `godot --headless --path . --editor --quit`.
- Focused test: `godot --headless --path . --script res://tests/backrooms_portal_director_test.gd`.

## Validation status

- Static patch assertions: passed before commit (unique parser replacement, unique workflow guard replacement, boundary and overflow fixtures present).
- GitHub Actions exact-head Full Compatibility Gate: pending after this commit.
- Full log audit: pending.
- Local Godot executable is unavailable in this environment; no local Godot runtime result is claimed.

## Limitations and next steps

- PR #347 remains Draft until its new exact-head Full Gate and all focused workflows pass, and the full log is scanned for actual Godot diagnostics.
- PR #348 is stacked on #347 and already carries the same parser correction; after #347 is validated, reconcile the updated parent SHA into #348 and rerun #348's exact-head gate.
- PR #383 remains a validated source branch, not a merged dependency. Its branch ancestry is not copied.
- No main merge. main remains `65b2cabc751637729d58f64c9633f888d3c8b74c`.

## Exact-head CI finding and import-order correction — 2026-11-20

- First exact-head Full Gate [44651496125](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/44651496125) completed with 18/19 associated workflows successful; the Full Gate failed at step #30, Backrooms portal playground integration.
- The corrected portal-director test itself passed at step #25 and printed `BackroomsPortalDirector tests passed.` with the new captured-output guard; no signed-64 conversion errors were present in that step.
- The unrelated downstream failure was an import-order defect: `BackroomsPortalPlayground.gd` preloads `assets/textures/backrooms_wallpaper.svg`, but the root editor invocation omitted `--import`. Godot reported no resource loaders for the SVG, the script failed to attach, and the integration test then saw a plain Node3D without `get_current_level()` and timed out. The method exists in the source; the script had failed to load first.
- Ported the already validated root-import hardening from the #348 source: use `godot --headless --path . --editor --import --quit`, then require `backrooms_wallpaper.svg.import`, `backrooms_carpet.svg.import`, and `.godot/imported` before running scene tests.
- New commit: pending exact-head CI. This corrects the test environment/import order; no gameplay or asset source changes.
