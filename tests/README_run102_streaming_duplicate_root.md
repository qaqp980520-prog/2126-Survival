# Run 102 — async duplicate staged-root guard

## Problem

The async streaming director stages detached chunk roots across frames before committing them to MineralChunkController. A factory could return the same still-detached Node3D instance for two coordinates. The per-result validity/parent check accepted both because neither had been parented during staging. The later commit would reject the second registration and rely on rollback.

## Production change

MineralGridStreamingDirector._run_async_sync_request() now compares each validated factory result against already staged root instances. If the same object is returned twice, the request fails in load_factory before controller registration, releases the staged set, and reports duplicate_staged_root_rejected. The diagnostic cancellation reason is factory_reused_staged_root.

The synchronous path already catches reuse after the first root is parented; this change closes the async multi-frame staging gap without changing sync behavior, chunk IDs or world-save schema.

## Regression

Run from repository root:

    godot --headless --path . --script res://tests/mineral_grid_streaming_duplicate_staged_root_test.gd

The fixture factory deliberately returns one shared detached Node3D twice. The test verifies rejection on the second result, zero controller registrations, empty director/controller ownership maps, cleared staging state, released weak reference, terminal request lock and a specific diagnostic reason.

## Dependencies and limits

Godot 4.3+; no new assets, plugins, network dependencies or world-save migration. Local Godot executable is unavailable in this run; exact engine validation is through cloud Godot 4.3 CI. Rendered GUI/GPU and iPhone QA remain separate.
