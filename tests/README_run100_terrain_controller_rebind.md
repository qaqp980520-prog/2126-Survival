# Run 100 — controller-driven terrain patch rebind regression

File: tests/mineral_chunk_controller_terrain_rebind_test.gd

The test exercises the production MineralChunkController load/unload path rather than calling SurfaceTerrainTransitionColliderManager directly.

## Scenario

1. Bind the production mineral registry and WorldObjectStateRegistry.
2. Load four chunk roots containing one SurfaceTerrainPatch each at a 2×2 checkerboard junction.
3. Apply schema-1 patch states (NW/SE high metal, NE/SW low soil) and verify four shared corner caps and four shared edge ramps.
4. Unload the south-east chunk. Verify the old patch instance is released and the four-way cap is removed. The remaining NW/NE/SW patches form an incomplete L junction: its two perpendicular seams meet at one patch corner, so the resolver blocks both ramps with `step_fallback`, reports the blocked south-east corner, and preserves the three patches' base collision. This is intentional safe behavior until all four patches are present.
5. Reload the same chunk ID with a new patch instance. Verify the saved height/material are restored by the same stable ID, then verify four caps/four ramps and the correct two incident shared edges are rebuilt.
6. Unload all chunks and verify the manager owns no stale caps/ramps while the replacement patch state remains in the world-object registry.

## Dependencies and execution

- Godot 4.3+.
- Uses MineralChunkController, MineralVeinRegistry, WorldObjectStateRegistry and SurfaceTerrainPatch from the root project.
- Run from the repository root with: godot --headless --path . --script res://tests/mineral_chunk_controller_terrain_rebind_test.gd.
- No production code or world-save schema change is required.

## Validation status

The first focused Run 94–100 check exposed an incorrect test expectation: an incomplete three-patch L junction must retain the safe `step_fallback`, not two shared ramps. The regression now asserts zero shared ramps, one deterministic south-east fallback report, disabled shared-side ownership and intact base collision. Exact-head full/focused Godot 4.3 CI must be rerun after this correction. No local Godot executable is available in this environment.
