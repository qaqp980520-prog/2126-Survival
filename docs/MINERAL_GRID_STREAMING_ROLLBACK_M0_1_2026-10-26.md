# MineralGridStreamingDirector — transactional unload rollback M0.1

Date: 2026-10-26

## Problem found

The director already loaded all desired chunks before unloading stale ones. However, if stale chunk A unloaded successfully and stale chunk B then failed to unload, the method returned false after A had already been removed. The active set was therefore partially changed despite a failed synchronization.

## Change

- Record each stale chunk ID and grid coordinate after its unload succeeds.
- If a later stale unload fails, first roll back chunks newly loaded for the requested position.
- Recreate and reload previously unloaded stale chunks using the same stable IDs and factory callback. The registry/controller can restore their persisted mineral state.
- Report a rollback failure with push_error instead of silently claiming the previous active set was preserved.
- Add tests/mineral_grid_streaming_transaction_test.gd with a fake controller that fails exactly on the second stale unload, then verifies both the director's managed IDs and controller's loaded IDs exactly match the original 3x3 set.

## Dependencies and import

Godot 4.3; existing MineralGridStreamingDirector, MineralChunkController contract and a synchronous chunk factory. No external addons.

## Validation status

Static review only until the exact branch's Godot 4.3 CI finishes. The test is included in the PR workflow and must pass before merge. No local Godot binary, GUI test, or iPhone test is claimed.

## Limits / next step

If the factory persistently fails while restoring old chunks, full rollback cannot be guaranteed; the director emits an error and returns failure. Future production integration should expose rollback diagnostics to the world controller and consider staged/detached chunk construction.
