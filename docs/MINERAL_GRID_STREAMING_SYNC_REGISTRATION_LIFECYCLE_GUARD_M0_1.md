# Mineral Grid Streaming Synchronous Registration Lifecycle Guard M0.1

## Asset identity and dependencies

- Production source: `systems/MineralGridStreamingDirector.gd`.
- Runtime dependency: `systems/MineralChunkController.gd` and the root Godot project.
- Deterministic test fixture: `tests/helpers/FakeMineralChunkController.gd`.
- Regression suite: `tests/mineral_grid_streaming_sync_registration_lifecycle_test.gd`.
- Engine target: Godot 4.3 headless; no external assets, plugins, network services or save migration.

## Finding

The synchronous `sync_to_world_position` path checked Controller lifecycle after the chunk factory callback but did not revalidate it after `Controller.load_chunk` returned. A Controller could detach or queue itself during registration, including on the ninth/final chunk, while the Director continued as if the requested window had committed.

## Behavior

- Verify that `load_chunk` actually registered the requested chunk.
- Recheck Controller instance validity, scene-tree membership and queued-for-deletion state immediately after the callback.
- Record a newly registered chunk before rollback so failed cleanup remains represented in the Director ownership mirror.
- Roll back the full newly loaded window when a live Controller detaches.
- Never call rollback methods on a Controller queued for deletion.
- Report incomplete cleanup when owner teardown, rather than a rollback call, is responsible for releasing child roots.

## Regression coverage

1. A live Controller detaches during the ninth/final registration: all nine newly registered chunks are unloaded and Director ownership is cleared.
2. A Controller queues itself during its only registration: no rollback method is invoked on the queued owner; owner teardown releases the child root.
3. A Controller queues itself during the ninth registration after eight prior loads: no rollback method is invoked, the Director mirror is cleared, incomplete rollback is reported, and owner teardown releases all nine roots.

## Import and test

Open the repository root `project.godot` in Godot 4.3. The regression is run with:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/mineral_grid_streaming_sync_registration_lifecycle_test.gd
```

## Compatibility and limitations

- Public Director method signatures are unchanged.
- Chunk IDs and world-save schema are unchanged.
- Asynchronous staging and commit behavior are unchanged.
- The fake Controller's lifecycle callbacks are test-only.
- Headless CI does not verify rendered GUI/GPU behavior or physical iPhone behavior.
- The candidate must pass both the focused lifecycle workflow and the full Godot 4.3 compatibility gate before merge.
