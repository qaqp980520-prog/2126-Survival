# Run 107 — Synchronous controller lifecycle regression

The async streaming path already requires a live controller that remains inside the scene tree and is not queued for deletion. The synchronous `sync_to_world_position` and `recover_to_world_position` entry points previously checked only null/instance validity, so a controller detached after binding or queued for deletion could still receive new chunk operations.

Run 107 centralizes the controller readiness contract and applies it to synchronous sync, recovery and async dependency checks.

The regression covers:
- a successful nine-chunk baseline window;
- a factory callback that detaches the bound controller after the sync entry check, proving the Director revalidates after callbacks and frees the uncommitted candidate;
- detaching the bound controller from the scene tree, then attempting sync and recovery;
- confirming the factory is not called and the Director's managed IDs remain unchanged;
- reattaching the same controller and successfully resuming sync;
- queueing the bound controller for deletion, then attempting sync and recovery before the next frame;
- confirming both calls reject before factory invocation and preserve the managed IDs.

Run with Godot 4.3+ from the repository root:

```sh
godot --headless --path . --script res://tests/mineral_grid_streaming_sync_controller_lifecycle_test.gd
```
