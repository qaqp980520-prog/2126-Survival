# M0.1.105 — Route Transfer Ownership-Lookup Ordering

## Purpose

Strengthen PR #430's production stale-route transfer guard with an observable positive control. The existing test asserted that stale and malformed route snapshots return `route_snapshot_stale`, but its message claimed that owner lookup was skipped without instrumenting the ledger call boundary.

This revision proves both sides of the ordering contract:

1. A current, structurally valid route reaches exactly one ownership-record lookup.
2. A stale or malformed route is rejected before `BackroomsEntityOwnershipLedger.get_record()` is called.

## GitHub asset

- PR: [#430 — production stale-route ownership-transfer guard](https://github.com/qaqp980520-prog/2126-Survival/pull/430).
- Branch: `test/backrooms-route-snapshot-transaction-2026-11-24-run409`.
- Parent PR #429 exact HEAD: `b8ead3491e46a196dd3dd5b8bb8bf92a05a42d03`.
- Starting candidate HEAD: `88fddde5cff457371f81e08bc396b5d23e071455`.
- Safety backup: `backup/pr430-before-owner-lookup-probe-2026-11-24-run410`.

## Files

- `tests/backrooms_cell_route_planner_test.gd` — adds a counting RefCounted ledger probe and tests the lookup-order boundary.
- `.github/workflows/godot-validation.yml` — requires this version record and the dedicated lookup-order success marker.
- `docs/BACKROOMS_ROUTE_TRANSFER_LOOKUP_ORDER_M0_1_105.md` — this version record.
- Existing M0.1.104 route-snapshot guard remains the parent asset.

## Dependencies and import

- Godot 4.3 root project.
- `BackroomsMazeCellRuntime`, `BackroomsMazeStreamState`, `BackroomsCellRoutePlanner`, `BackroomsMazeLayout`, and the `BackroomsEntityOwnershipLedger` interface.
- No new scene, external asset, plugin, autoload, project setting, production runtime code, or save-schema change.
- From the repository root, run:

```bash
godot --headless --path . --script res://tests/backrooms_cell_route_planner_test.gd
```

## Regression contract

- Replace the configured ledger only for the transfer-gate probe with a counting test double exposing `configured` and `get_record_calls`.
- Positive control: a current valid route reaches `get_record` exactly once; the deliberately empty test ledger then returns the expected `entity_owner_record_mismatch`.
- Negative controls: mismatched configuration revision, canonical cell keys, success-flag type, seed type, endpoints, and edge directions each return `route_snapshot_stale` while the ledger call count remains unchanged.
- Restore the real production ledger before performing the active stream-window shift, so the test double cannot affect streaming or ownership reconstruction.
- Reinstall the counting probe after the shift and verify the old route is rejected without a ledger lookup.
- Emit a dedicated marker and require it in the Full Compatibility Gate workflow.

## Validation status — code/test HEAD 69b103a

- Exact code/test candidate: `69b103aa6e609da60cd5a5f8e5cca1b080baeba9`.
- Fresh PR-triggered matrix: 19/19 workflows succeeded.
- Godot Full Compatibility Gate [45403729819](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45403729819): 571/571 numbered validation steps succeeded; 574/574 total step records succeeded including 3 post-job steps.
- Route planner step #25 succeeded and the workflow accepted the dedicated lookup-order marker.
- Production integration steps #222–#227 all succeeded: SurfaceWorld integration, combined Backrooms save envelope, SurfaceWorld file persistence, SurfaceWorld/Hound durable round-trip, keyboard/touch Save/Load, and survival test hub smoke.
- Full Gate log: 7,978,358 characters / 87,213 lines / 80,441 PASS matches. Actual Script/Parse/Runtime/ERROR/FAIL diagnostics: 0; ObjectDB leaks: 0; Orphan StringName: 0.
- 26 retained warnings, not claimed fixed: 19 filled `draw_rect` width warnings; 1 nested KROLL project warning; 1 mineral stale-unload rollback warning; 3 SurfaceWorld restore rollback warnings; 2 synchronous mineral registration rollback warnings.
- Xvfb/Mesa Backrooms rendering job was skipped by the workflow branch-prefix condition. This metadata-only route/ownership test does not claim rendering, physics, GPU, FPS, or mobile-device validation. No local Godot executable is available.
- Full Gate produced no artifact. The route test's new positive/negative lookup-order assertions were visible in the Full Gate log.

A documentation-only finalization commit follows this code/test HEAD so the version record can carry the measured result. The new PR head must complete its own fresh workflow matrix before integration; the above run is not reused as final-head evidence.

## Limitations

- Uses the existing metadata-only production runtime fixture; it does not validate rendered geometry, physics, player movement, or AI pursuit.
- The counting ledger is a test double used only to observe the call boundary; it does not replace the real ownership-ledger integration tests elsewhere in the Full Gate.
- No hardware-GPU, FPS, or mobile-device result is claimed.
- Local environment has no `godot` or `godot4` executable; exact engine evidence must come from GitHub Actions.
