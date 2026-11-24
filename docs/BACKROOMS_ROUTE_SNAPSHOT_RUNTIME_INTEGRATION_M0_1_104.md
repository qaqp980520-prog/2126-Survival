# M0.1.104 — Production Route Snapshot Transfer Guard

## Purpose

Extend the existing loaded-cell route planner freshness suite with one missing integration assertion: the production `BackroomsMazeCellRuntime.transfer_entity_to_next_cell()` gate must reject a route snapshot from a previous stream generation before it performs entity-owner lookup or any ownership transfer.

This is deliberately an extension of the existing M0.1.69 route-snapshot contract, not a second implementation of route freshness or maximum-window stress.

## GitHub asset

- PR: #430 — production stale-route ownership-transfer guard.
- Branch: `test/backrooms-route-snapshot-transaction-2026-11-24-run409`.
- Parent PR #429 exact HEAD: `b8ead3491e46a196dd3dd5b8bb8bf92a05a42d03`.
- Candidate HEAD after this focused correction: pending exact-head CI.

## Files

- `tests/backrooms_cell_route_planner_test.gd` — adds configuration-revision and canonical-cell-key tampering assertions plus the production stale-transfer rejection assertion.
- `.github/workflows/godot-validation.yml` — requires this version record and checks the dedicated transfer-guard success marker from the existing route-planner test step.
- `docs/BACKROOMS_ROUTE_SNAPSHOT_RUNTIME_INTEGRATION_M0_1_104.md` — this version record.

## Existing coverage retained

M0.1.69 / PR #397 already exercises the real metadata-only `BackroomsMazeCellRuntime` for route planning, fresh snapshot acceptance, edge/type/endpoint tampering, stream-window shift invalidation, fresh route acceptance, disconnected windows, expansion budgets and 289-cell maximum-window stress. This follow-up does not duplicate those tests.

## New regression coverage

- Reject a snapshot with a mismatched `configuration_revision`.
- Reject canonical `cell_keys` that no longer match the route's `cell_path`.
- After the existing active stream shift invalidates the old route, call `transfer_entity_to_next_cell` with that stale route.
- Require the explicit `route_snapshot_stale` result, proving the production ownership-transfer gate fails closed before owner-record lookup.
- Emit and require a dedicated success marker from the existing route-planner suite.

## Dependencies and import

- Godot 4.3 root project.
- Existing `BackroomsMazeCellRuntime`, `BackroomsMazeStreamState`, `BackroomsCellRoutePlanner`, `BackroomsMazeLayout`, and `BackroomsEntityOwnershipLedger`.
- No new scene, external asset, plugin, autoload, project setting, or save-schema change.
- Run through the existing Full Compatibility Gate command for `tests/backrooms_cell_route_planner_test.gd`.

## Validation status

Pending exact-head Godot 4.3 Full Compatibility Gate and complete log audit. The initial candidate's CI is not reused after this test-scope correction; all checks must pass on the new final HEAD.

## Limitations

- Uses the existing metadata-only production runtime fixture; it does not validate rendered geometry, physics, player movement, or AI pursuit.
- No hardware-GPU, FPS, or mobile-device test is claimed.
- No production runtime code or save format is changed.
- Local environment has no `godot` or `godot4` executable; exact engine evidence must come from GitHub Actions.

## Next steps

1. Complete exact-head CI and inspect the route-planner test log for the dedicated transfer-guard marker.
2. Audit the Full Gate log for actual Script/Parse/Runtime/ERROR/FAIL diagnostics and classify retained warnings.
3. Update this record, PR #430 and the Notion asset/work index with the exact final HEAD and evidence.
4. Obtain independent review and preserve parent-first integration; revalidate every resulting HEAD.