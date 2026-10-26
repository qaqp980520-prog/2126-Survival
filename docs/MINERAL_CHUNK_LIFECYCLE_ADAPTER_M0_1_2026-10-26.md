# Mineral Chunk Lifecycle Adapter M0.1 — 2026-10-26

## Purpose
Provide a small, testable boundary for a future world/chunk streamer to register mineral nodes on chunk load and preserve their stable-ID records before node destruction on chunk unload.

## Contract
- The world owner calls `load_chunk(chunk_id, veins_by_local_id, now_unix)` after creating mineral nodes.
- Stable IDs are deterministic: `<chunk_id>/vein/<local_vein_id>`.
- Duplicate live chunk IDs cannot silently replace a different node map.
- The world owner calls `unload_chunk(chunk_id, now_unix)` before freeing chunk nodes.
- The adapter asks the registry to capture each vein state; unloaded records remain available to save/load and later chunk reload.
- `get_loaded_chunk_ids()` is diagnostic state only; it does not create or stream chunks.

## Files
- `systems/MineralChunkLifecycleAdapter.gd`: lifecycle boundary.
- `tests/mineral_chunk_lifecycle_adapter_test.gd`: load/unload/reload, elapsed regeneration, and duplicate chunk protection.
- `.github/workflows/godot-validation.yml`: guarded headless test step.

## Validation
Must pass the full Godot headless CI before merge. No local Godot execution, visual playtest, or iPhone test is claimed.

## Integration limit
This is an adapter interface, not a full world streamer. The repository does not yet contain a formal chunk controller; that controller must call these methods and own node creation/destruction. The adapter must be integrated into that controller before claiming end-to-end world streaming support.
