# M0.1.104 — Production Route Snapshot Runtime Integration

## Purpose

Verify the immutable route-snapshot contract against the real `BackroomsMazeCellRuntime`, rather than only a fake runtime used by the movement-driver unit tests. A route planned for one committed stream window must be rejected after a later window commit or runtime deactivation, and stale transfer attempts must fail closed before touching entity ownership.

## GitHub asset

- PR: #430 — production route snapshot invalidation integration.
- Branch: `test/backrooms-route-snapshot-transaction-2026-11-24-run409`.
- Parent PR #429 exact HEAD: `b8ead3491e46a196dd3dd5b8bb8bf92a05a42d03`.
- Candidate HEAD: pending exact-head CI.

## Files

- `tests/backrooms_maze_cell_runtime_test.gd` — adds a real production-runtime route snapshot lifecycle fixture.
- `.github/workflows/godot-validation.yml` — requires this version record and checks the dedicated route-snapshot integration success marker in the existing runtime test step.
- `docs/BACKROOMS_ROUTE_SNAPSHOT_RUNTIME_INTEGRATION_M0_1_104.md` — this version record.

## Dependencies and import

- Godot 4.3 root project.
- `BackroomsMazeCellRuntime`, `BackroomsMazeStreamState`, `BackroomsCellRoutePlanner`, `BackroomsMazeLayout`, and `BackroomsEntityOwnershipLedger`.
- Uses the existing root-project headless runtime test; no new external assets, plugins, autoloads, project settings, scenes, or save-schema changes.
- Run through the existing Full Compatibility Gate command for `tests/backrooms_maze_cell_runtime_test.gd`.

## Regression coverage

- Prepare and activate a real metadata-only Level 1 radius-one production runtime.
- Plan the guaranteed parent-edge route from `(0,0)` to `(1,0)` and confirm the current snapshot is accepted.
- Reject modified stream-generation and configuration-revision fields.
- Reject cell-key tampering and edge-direction tampering that no longer matches the path.
- Commit a one-cell eastward stream shift and verify the generation advances exactly once.
- Confirm the prior-window snapshot becomes stale.
- Call `transfer_entity_to_next_cell` with that stale snapshot and require the explicit `route_snapshot_stale` rejection before ownership lookup or mutation.
- Replan from `(1,0)` to `(2,0)`, confirm the new snapshot is current, then deactivate the runtime and confirm the snapshot is no longer current.

## Validation status

Pending exact-head Godot 4.3 Full Compatibility Gate and full-log audit. Do not reuse parent PR #429's historical CI as evidence for this child candidate.

## Limitations

- Uses the production runtime in metadata-only mode to isolate route-snapshot and stream-generation semantics; it does not validate rendered geometry, physics, player movement, or AI pursuit.
- This is not a hardware-GPU, FPS, or mobile-device test.
- No production runtime behavior or save format is changed.

## Next steps

1. Complete exact-head CI and inspect the runtime-test log for the dedicated success marker.
2. Audit Full Gate logs for actual Script/Parse/Runtime/ERROR/FAIL diagnostics and retained warnings.
3. Update this record and the Notion asset/work records with the exact candidate HEAD and evidence.
4. Obtain independent review for the parent stack before any parent-first integration; revalidate every resulting HEAD.
