# Run 101 — async streaming dependency binding guard

## Purpose

A streaming request stages roots over multiple frames. Rebinding the controller or chunk factory during that interval could split one request across different dependencies, especially when the director has no committed chunks yet.

## Production change

MineralGridStreamingDirector.bind_controller() and bind_chunk_factory() reject binding changes while an async request is active. The public dependency properties now route direct assignments through those same guarded methods, preventing callers from bypassing the API checks. Controller replacement also remains blocked while managed chunks are owned; factory replacement is allowed after a request reaches a terminal state.

## Regression

tests/mineral_grid_streaming_binding_guard_test.gd starts the first 3×3 async request with an empty managed window, waits until a detached root is staged, attempts to replace both dependencies, and verifies:

- both binding API calls and direct property assignments are rejected during staging;
- controller replacement remains rejected after completion while the original controller still owns chunks;
- the factory can be replaced after the request reaches a terminal state;
- the active request ID and original dependencies remain unchanged;
- all nine roots are produced by the original factory and committed to the original controller;
- the replacement controller receives no roots;
- controller and director ownership maps remain identical;
- factory rebinding is allowed again after the request becomes terminal.

## Execution

Run from repository root:

    godot --headless --path . --script res://tests/mineral_grid_streaming_binding_guard_test.gd

Godot 4.3+; no world-save schema change. Local Godot executable availability is tracked separately from cloud CI.
