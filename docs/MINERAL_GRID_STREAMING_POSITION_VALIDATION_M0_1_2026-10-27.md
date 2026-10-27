# Mineral grid streaming finite-position validation M0.1

## Problem
The streaming director converted world-space coordinates to integer grid cells using floor operations without rejecting NaN or infinity. The recovery method also reconciled the director's managed map before the target position was validated by the subsequent sync call. An invalid position could therefore produce undefined grid selection or mutate recovery bookkeeping before the request was rejected.

## Change
- Reject non-finite X/Y/Z coordinates before grid selection in `sync_to_world_position()`.
- Reject non-finite coordinates at the start of `recover_to_world_position()`, before reading/reconciling controller IDs.
- Make `get_grid_coordinate()` return `Vector2i.ZERO` for invalid chunk dimensions or non-finite positions.
- Keep the last-sync report phases explicit: `validation` for normal sync and `recovery_validation` for recovery.

## Regression coverage
`tests/mineral_grid_streaming_position_validation_test.gd` seeds an existing controller chunk, then verifies NaN recovery and infinite sync are rejected without changing either controller IDs or the director's managed IDs. It also checks the coordinate helper's safe fallback.

## Dependencies and import
Godot 4.3+; uses the existing `MineralChunkController` interface and `tests/helpers/FakeMineralChunkController.gd`. Run through the root repository Godot validation workflow.

## Validation and limits
Local Godot executable is unavailable. This change is not considered engine-tested until the exact-head GitHub Actions workflow passes. The streaming director remains synchronous and factory-driven and is not yet connected to the production world generator.
