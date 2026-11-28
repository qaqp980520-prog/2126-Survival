# M0.3.53 — Corner-cap preservation on terrain unload preflight rejection

Date: 2026-11-28

## Purpose

Close the Run 473 test-coverage gap by verifying that a `MineralChunkController.unload_chunk()` rejected during `SurfaceTerrainAdjacencyBinder` preflight preserves the production transition-collider manager's already-committed shared corner caps, edge colliders, descriptors, and blocked-corner reports.

## Changed files

- `tests/mineral_chunk_controller_test.gd` — add `_test_failed_unload_preflight_preserves_corner_caps()` and register it in `_run_tests()`.
- `docs/MINERAL_CHUNK_CONTROLLER_CORNER_CAP_PREFLIGHT_PRESERVATION_M0_3_53.md` — this version record.

## Dependencies and import

- Godot 4.3 project.
- Existing `MineralChunkController`, `MineralVeinRegistry`, `WorldObjectStateRegistry`, `SurfaceTerrainPatch`, `SurfaceTerrainAdjacencyBinder`, and `SurfaceTerrainTransitionColliderManager` scripts.
- No new assets, plugins, autoloads, project settings, or save-schema changes.
- The test is included in the existing `tests/mineral_chunk_controller_test.gd` runner; no manual import step is required beyond the normal project import/test workflow.

## Regression scenario

- Load a 2×2 checkerboard of four terrain patches with alternating height levels 0 and 2. The four unequal-height seams meet at one eligible junction.
- Confirm four `shared_corner_cap` reports, four live corner-cap bodies, four edge transition colliders, and the committed descriptor/object-registry snapshots.
- Corrupt one remaining patch profile and attempt to unload the fourth chunk. Binder preflight must reject before live edge mutation and before collider-manager synchronization.
- Verify the departing chunk remains owned, every descriptor and report is unchanged, the corner-cap count and exact cap-body identities are unchanged, every edge-collider identity is unchanged, collision remains active, and the object registry is byte-for-byte equivalent.
- Repair the patch and retry unload. The new three-patch topology must be committed and the no-longer-eligible corner caps retired.

## Validation

- Static source/diff review: completed before push.
- Godot 4.3 Dedicated and Full Compatibility Gate: pending exact-head CI at the final commit; do not infer success from previous PR runs.
- Local Godot execution: unavailable in the authoring container; not claimed.

## Limitations

- This is a regression-coverage addition, not evidence of a confirmed production defect. The preflight code path is expected not to call `sync_transitions()` or `clear_all()`.
- Runtime rendering, GPU physics behavior, mobile devices, and target-hardware performance are not validated by this headless regression.

## Next steps

- Inspect exact-head CI and full logs.
- Keep PR #440 Ready for Review; do not merge until independent review and the parent-first stack reconciliation are complete.
- If the regression fails, fix the test or production logic on this existing PR branch and rerun exact-head validation.
