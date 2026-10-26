# Mineral Vein Registry M0.1 — 2026-10-26

## Purpose
Provide a stable-ID save/load registry for mineral vein nodes so world/chunk persistence can restore each vein independently of scene instance IDs.

## Runtime contract
- Register each loaded vein with a stable world/chunk identifier using `register_vein(stable_id, node)`.
- Duplicate IDs cannot silently replace another live vein.
- `to_save_dict()` serializes registered live veins in sorted stable-ID order under registry schema v1.
- `restore_save_dict(data, now_unix)` validates the envelope, every ID, and every vein payload before mutating live nodes; invalid batches are rejected atomically.
- On restore, each node loads its schema-v2 state and applies elapsed wall-clock regeneration. The node retains its existing schema-v1 compatibility.
- Unregister a node when its chunk unloads; pass the expected node to avoid unregistering a replacement by mistake.

## Files
- `systems/MineralVeinRegistry.gd`: stable-ID registry and save/load validation.
- `tests/mineral_catalog_test.gd`: registration, duplicate IDs, offline elapsed restore, capacity, invalid batch atomicity, unknown IDs, and unregister behavior.

## Validation status
This is a candidate implementation on a feature branch. It must pass the full Godot 4.3 headless workflow before merge. No local Godot execution, graphical playtest, or iPhone test is claimed.

## Integration limits
The registry is a reusable system, not yet wired into a complete world/chunk streaming manager. The world owner still needs to choose stable IDs and call register/unregister at chunk lifecycle boundaries.
