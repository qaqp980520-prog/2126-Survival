# Run 100 — controller-driven terrain patch rebind regression

File: tests/mineral_chunk_controller_terrain_rebind_test.gd

The test exercises the production MineralChunkController load/unload path rather than calling SurfaceTerrainTransitionColliderManager directly.

## Scenario

1. Bind the production mineral registry and WorldObjectStateRegistry.
2. Load four chunk roots containing one SurfaceTerrainPatch each at a 2×2 checkerboard junction.
3. Apply schema-1 patch states (NW/SE high metal, NE/SW low soil) and verify four shared corner caps and four shared edge ramps.
4. Unload the south-east chunk. Verify the old patch instance is released, the four-way cap is removed, and only the two remaining live ramps are retained.
5. Reload the same chunk ID with a new patch instance. Verify the saved height/material are restored by the same stable ID, then verify four caps/four ramps and the correct two incident shared edges are rebuilt.
6. Unload all chunks and verify the manager owns no stale caps/ramps while the replacement patch state remains in the world-object registry.

## Dependencies and execution

- Godot 4.3+.
- Uses MineralChunkController, MineralVeinRegistry, WorldObjectStateRegistry and SurfaceTerrainPatch from the root project.
- Run from the repository root with: godot --headless --path . --script res://tests/mineral_chunk_controller_terrain_rebind_test.gd.
- No production code or world-save schema change is required.

## Validation status

Pending exact-head full and focused Godot 4.3 CI. No local Godot executable is available in this environment.
