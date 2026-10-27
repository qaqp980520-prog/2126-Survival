# Mineral stream restore transaction M0.2 — 2026-10-27

## Scope

The surface streaming playground now treats stream-state restore as a transaction across player position, active chunk ownership, and the mineral registry snapshot.

## Behavior

- Validate the complete envelope and finite player position before mutation.
- Snapshot the currently serialized mineral registry before applying a candidate payload.
- Apply the candidate mineral state, then attempt to synchronize the requested chunk window.
- If target chunk generation or registration fails, preserve the original sync report, return the player to the prior position, reconcile the director from the controller's actual loaded IDs, and restore the pre-attempt mineral snapshot.
- Expose get_last_restore_report() with phase, rollback_complete, and target/recovery details so a world host can decide whether to retry or enter a safe state.
- Emit a warning if the rollback itself is incomplete; do not claim recovery succeeded merely because the restore function returned false.

## Files

- prototypes/SurfaceChunkStreamingPlayground.gd
- tests/surface_chunk_streaming_playground_test.gd
- .github/workflows/godot-validation.yml
- daily_games/KROLL_Vertical_Relay/

## Dependencies and import

Godot 4.3+ and the existing MineralChunkController, MineralVeinRegistry, and MineralGridStreamingDirector. Open daily_games/KROLL_Vertical_Relay/project.godot for the standalone game. The survival integration test runs from the root project using tests/surface_chunk_streaming_playground_test.gd.

## Regression coverage

The integration test injects a factory failure after at least one target chunk has loaded. It verifies the old player position, controller IDs, director IDs, saved vein IDs, and live ore count are restored, while the report preserves the original load_factory failure.

## Validation status

- PR #64 merged to main in commit e9d853fe0114e3432b7269f902fd579bbcbe9dcc.
- Exact-head PR CI Run #297 (40442929654) succeeded with all 72 required validation steps passing on c00be54a008978f2406ea35612d6d02609f1bcf8.
- Main-push CI Run #298 (40443291605) succeeded with all 72 required validation steps passing on e9d853fe0114e3432b7269f902fd579bbcbe9dcc.
- The fault-injection test confirms rollback of the previous position, active chunk IDs, saved vein IDs, and live ore count after a target factory failure.
- The Vertical Relay and surface streaming integration tests now own and free their watchdog Timer nodes. Other legacy diagnostics/Cipher Recall/Cargo Tugs/Vector Rally tests still print non-fatal ObjectDB leak warnings.
- No local Godot executable is available, so local GUI play and iPhone device testing are not claimed.

## Known limits

The surface playground remains an integration prototype, not the production world generator. The director is synchronous and factory-driven. If the recovery attempt itself fails, the report explicitly indicates incomplete rollback; a production host must decide how to pause streaming or retry safely.
