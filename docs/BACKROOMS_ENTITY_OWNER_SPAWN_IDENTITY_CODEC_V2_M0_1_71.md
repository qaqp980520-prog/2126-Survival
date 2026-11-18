# Backrooms Owner / Spawn Identity Runtime-State Codec v2 — M0.1.71

## Purpose

Prepare the existing mobile-entity persistence contract for ownership migration without changing the meaning of deterministic spawn identity. A roaming entity can eventually be owned by a different streamed cell than the cell in which it was deterministically spawned.

## Files

- `systems/BackroomsEntityRuntimeState.gd` — codec v2 adds immutable `spawn_cell_key` while retaining `cell_key` as the mutable owner-cell key.
- `systems/BackroomsMazeStreamState.gd` — accepts codec v1 and v2 payloads; writes the current codec v2.
- `tests/backrooms_maze_cell_runtime_test.gd` — covers v1 migration, v2 owner/spawn separation, and tampered spawn identity rejection.
- `.github/workflows/godot-validation.yml` — requires this contract document in the root validation inputs.

## Record contract

- `cell_key`: current owner cell; position is expressed in this cell's local coordinate space.
- `spawn_cell_key`: immutable deterministic spawn origin. AI behavior save validation and deterministic spawn descriptor validation use this key.
- `entity_id`, `spawn_algorithm_version`, `position`, `brain_state`, and `patrol_index` retain their existing meanings.
- The stable runtime-state key is `spawn_cell_key|entity_id`, so two entities of the same type may share one mutable owner cell without colliding. Codec v1 migration sets `spawn_cell_key = cell_key`, preserving the legacy key for unmigrated entities.
- Codec v1 records did not contain `spawn_cell_key`; migration explicitly sets it equal to the old `cell_key`.
- New captures and saves emit codec v2. A v2 record missing `spawn_cell_key` is rejected.
- Owner-cell position bounds are checked against `cell_key`; deterministic spawn and AI identity are checked against `spawn_cell_key`.
- Restore requires the destination cell root to match `cell_key` and the entity's immutable `spawn_cell` metadata to match `spawn_cell_key`. Runtime lookup is keyed by immutable spawn identity, not by mutable owner location.

## Validation

The root Godot 4.3 Full Compatibility Gate runs the existing Backrooms maze cell runtime test. The new cases verify:
- ordinary same-cell records explicitly preserve identical owner and spawn keys;
- codec v1 payloads load and re-save as codec v2;
- a valid deterministic spawn identity can be stored with a distinct owner cell;
- changing the spawn key to a cell that does not contain that deterministic spawn is rejected;
- two same-type entities with different spawn cells can share one owner cell and retain distinct runtime-state keys.

## Explicit boundary

This is a persistence-format prerequisite only. It does not yet create a migrated entity under a different owner cell, reparent live CharacterBody3D nodes, reconstruct migrated entities after owner-cell unload/reload, connect the ownership ledger to the runtime, or enable cross-cell roaming. Those operations must be implemented atomically in a later integration PR, including Combined World Save round-trip and rollback tests. Until then, production movement remains cell-local.

## Next

Integrate the v2 record with the ownership ledger and maze-cell runtime: spawn immutable identity from the original descriptor, place the live node under the current owner-cell root, capture position relative to that owner, reconstruct migrated entities when owner cells load, and persist the ledger plus entity state in one validated world-save transaction. Do not enable roaming until exact-head tests cover commit, reparent rollback, unload/reload, and combined save/restore.
