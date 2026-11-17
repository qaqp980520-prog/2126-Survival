# M0.1.53 — Backrooms Portal RNG Int64 Guard at SurfaceWorld Persistence Branch

## Purpose

Correct the first divergent SurfaceWorld portal-persistence branch that reintroduced the overflow-prone RNG save parser after the clean #337 parent. This is the common ancestor of the #340–#347 persistence/runtime descendants and the #363/#364 production entity-spawn descendants.

## Exact evidence

- PR #339 head: `ff690871a42846c1ae59e72e10605d01fe61bf5d`; its `BackroomsPortalDirector.gd` had the old overflow-prone conversion.
- The same defect is independently confirmed in descendants:
  - PR #344 Full Gate [#43342666633](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43342666633), job `131614480477`: two real Godot errors.
  - PR #345 Full Gate [#43358973711](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43358973711), job `131667707101`: two real Godot errors.
  - PR #346 Full Gate [#43363044551](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43363044551), job `131680843434`: two real Godot errors.
  - PR #347 Full Gate [#43372327505](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43372327505), job `131710737640`: two real Godot errors.
  - PR #363 Full Gate [#43652330458](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43652330458), job `132623330611`: two real Godot errors.
  - PR #364 Full Gate [#43654319161](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43654319161), job `132629413357`: two real Godot errors.
- PR #335–#337 exact-head logs were independently scanned and contained zero actual Godot diagnostics; #337 has the corrected parser. The regression first appears in PR #339, which modifies `BackroomsPortalDirector.gd` and the portal-director test.
- PR #348 also contains the corrected parser and its exact-head Full Gate log scan found zero actual Godot diagnostics.

## Implementation

- Validate canonical signed-64-bit decimal strings lexically before calling `int()`.
- Accept exact signed-64-bit min/max; reject overflow, underflow, malformed and non-canonical values without overflowing conversion.
- Add boundary and overflow/underflow regression coverage while preserving rejected-load atomicity.
- Capture portal-director Godot output, use a 45-second timeout with 5-second hard-kill grace, reject `SCRIPT ERROR`, `ERROR:` and `FAIL:`, and require the exact success marker.

## Files

- `systems/BackroomsPortalDirector.gd`
- `tests/backrooms_portal_director_test.gd`
- `.github/workflows/godot-validation.yml`
- `docs/BACKROOMS_PORTAL_RNG_INT64_SURFACEWORLD_STACK_M0_1_53.md`

## Dependencies and import

- Corrective child PR #383 targets PR #339's feature branch.
- PR #339 is the first divergent child of the corrected #337 SurfaceWorld spawn-window branch.
- Descendants: #340 → #341 → #342 → #343 → #344 → #345 → #346 → #347 → #348; the #363/#364 entity-spawn branch descends from #345.
- Godot 4.3; no third-party dependencies, autoloads, Project Settings, scenes or external assets changed.
- Import: `godot --headless --path . --editor --quit`.
- Focused test: `godot --headless --path . --script res://tests/backrooms_portal_director_test.gd`.

## Validation status

- Static patch assertions passed: parser replacement exactly once; helper inserted exactly once; signed-64-bit min/max and overflow/underflow cases added; raw portal-director workflow command replaced exactly once.
- Exact-head Full Gate for PR #383 is pending; no new engine pass is claimed.
- Local Godot is unavailable; engine validation must run in GitHub Actions Godot 4.3.

## Scope and limitations

- No gameplay RNG algorithm, portal spawn policy, serialized RNG field format, save schema or entity-spawn behavior changes.
- No `daily_games/` files or commands changed.
- No GPU, graphical Portal Activation, iPhone or target-device performance claim.

## Next steps

1. Complete PR #383 exact-head focused and Full Gate runs; inspect the captured portal step and complete log.
2. Obtain independent review and integrate #383 into PR #339's branch only.
3. Rerun PR #339 exact head and verify no engine diagnostics.
4. Revalidate descendants in parent order; keep #340–#347 and #363/#364 Draft until their exact-head logs are clean.
5. Do not merge directly to main.
