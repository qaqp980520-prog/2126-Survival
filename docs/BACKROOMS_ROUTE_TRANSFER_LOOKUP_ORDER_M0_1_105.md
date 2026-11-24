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

## Validation status

Pending exact-head GitHub Actions Godot 4.3 validation and complete log audit. No prior PR #430 workflow result is reused for the new commit.

## Limitations

- Uses the existing metadata-only production runtime fixture; it does not validate rendered geometry, physics, player movement, or AI pursuit.
- The counting ledger is a test double used only to observe the call boundary; it does not replace the real ownership-ledger integration tests elsewhere in the Full Gate.
- No hardware-GPU, FPS, or mobile-device result is claimed.
- Local environment has no `godot` or `godot4` executable; exact engine evidence must come from GitHub Actions.
