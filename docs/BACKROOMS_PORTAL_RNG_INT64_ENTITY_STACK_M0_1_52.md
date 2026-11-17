# M0.1.52 — Backrooms Portal RNG Int64 Guard on Entity Spawn Stack

## Purpose

Remove a verified Godot 4.3 false-green in the Backrooms portal-director test inherited by the production entity-spawn stack. Oversized positive and negative RNG save strings previously reached `int()`, emitted engine `ERROR:` diagnostics, and were followed by a success banner.

## Evidence

- PR #363 exact HEAD: `904c6d3e33a06ad3d1e046c6e318bef9c3d5b926`.
- Parent exact-head Full Gate: [#43652330458](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43652330458), job `132623330611`.
- PR #364 exact HEAD: `16af0fae0cb646b25344af2b7fd0df79074d2b01`.
- Child exact-head Full Gate: [#43654319161](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43654319161), job `132629413357`.
- Both full logs contain two actual Godot 4.3 diagnostics for oversized positive and negative signed-64-bit RNG strings in the raw `Run Backrooms portal director tests` step. The step printed its success banner after the errors; therefore neither historical green workflow is accepted as a clean engine pass.
- PR #363 and #364 were returned to Draft pending this correction.

## Implementation

- Validate the RNG save string lexically against signed 64-bit bounds before calling `int()`.
- Accept exact signed-64-bit minimum and maximum.
- Reject overflow, underflow, malformed and non-canonical strings without invoking an overflowing conversion.
- Keep rejected-load atomicity assertions.
- Capture the portal-director Godot output, apply a 45-second timeout with 5-second hard-kill grace, reject `SCRIPT ERROR`, `ERROR:` and `FAIL:`, and require the exact success marker.

## Files

- `systems/BackroomsPortalDirector.gd`
- `tests/backrooms_portal_director_test.gd`
- `.github/workflows/godot-validation.yml`
- `docs/BACKROOMS_PORTAL_RNG_INT64_ENTITY_STACK_M0_1_52.md`

## Dependencies and import

- Corrective child PR #382 targets PR #363's branch.
- PR #363 remains the parent of PR #364; #364 must be revalidated after this fix propagates.
- Ancestors: PR #345 → #363 → #364.
- Godot 4.3; no third-party dependencies, autoloads, Project Settings, scene or external asset changes.
- Import: `godot --headless --path . --editor --quit`.
- Focused regression: `godot --headless --path . --script res://tests/backrooms_portal_director_test.gd`.

## Validation status

- Source and test patch ported from the independently validated corrective implementation in PR #373, adapted to the #363 entity-spawn branch.
- Static patch assertions: parser replacement exactly once; overflow-safe helper inserted exactly once; signed-64-bit min/max and overflow/underflow cases added; raw CI command replaced exactly once with captured-output guard.
- GitHub Actions exact-head Full Gate: pending for PR #382. No Godot engine pass is claimed for this new branch yet.
- Local Godot executable unavailable; engine validation must run in GitHub Actions Godot 4.3.

## Scope and limitations

- No gameplay RNG algorithm, portal spawn policy, serialized field format, save schema, maze stream schema, or entity-spawn behavior changes.
- No `daily_games/` file or command changes.
- The fix prevents signed-64-bit conversion diagnostics and makes the portal test fail closed on engine errors; it does not validate graphical Portal Activation, GPU rendering, iPhone behavior, or device performance.

## Next steps

1. Complete PR #382 exact-head focused and full Godot 4.3 gates.
2. Scan the complete Full Gate log and confirm the two overflow probes are rejected without engine diagnostics.
3. Obtain independent review and integrate #382 into PR #363's feature branch only.
4. Rerun PR #363 at its new exact HEAD and full-log scan.
5. Propagate the corrected parent into PR #364, rerun its exact-head Full Gate and full-log scan, then consider Ready for Review.
6. Do not merge any part of this stack directly to main.
