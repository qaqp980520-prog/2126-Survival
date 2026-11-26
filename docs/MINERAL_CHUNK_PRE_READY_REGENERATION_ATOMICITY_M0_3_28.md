# M0.3.28 — Defer Mineral Ready Regeneration During Atomic Chunk Restore

Date: 2026-11-26

## Problem

MineralChunkController.load_chunk() attaches the candidate root before calling the atomic Registry batch API so that world-object and terrain participants can be restored. MineralMiningNode._ready() previously applied wall-clock regeneration immediately on attachment. If a later mineral participant rejected the batch, the Controller detached the caller-owned root, but an earlier node could already have had its authored remaining_units and last_regen_unix advanced by _ready(). The Registry transaction itself remained atomic, but the caller-owned scene was not unchanged.

The same ordering also made successful new-vein loads nondeterministic when now_unix was explicitly supplied: _ready() used the system clock before the Registry transaction.

## Implementation

- Add a one-shot chunk-load restore guard to MineralMiningNode: begin_chunk_load_restore(), end_chunk_load_restore(), and is_chunk_load_restore_pending().
- While the guard is active, _ready() still creates the interaction area and initializes visual/visibility state, but does not initialize last_regen_unix or apply wall-clock regeneration.
- MineralChunkController.load_chunk() validates the guard capability and starts the guard for every incoming mineral node immediately before attaching the root.
- Clear the guard on every post-attachment failure path and after successful registration.
- In MineralVeinRegistry.register_veins_atomic(), when a new node has no persisted record and the Controller deferred _ready() regeneration, apply elapsed regeneration on the detached probe at the caller-supplied now_unix before commit. Saved-record behavior continues to respect auto_apply_elapsed_time_on_restore.
- Add a regression that rejects a later saved-record mineral mismatch while the first incoming node has two elapsed regeneration intervals; the earlier caller-owned node must remain unchanged at the save-payload level and the guard must be cleared.
- Add a successful no-saved-record regression proving that an old authored timestamp is advanced exactly once at the explicit load timestamp, not at wall-clock _ready() time.

## Files

- systems/MineralMiningNode.gd
- systems/MineralVeinRegistry.gd
- systems/MineralChunkController.gd
- tests/mineral_chunk_controller_test.gd

## Dependencies and import

Godot 4.3 project; existing MineralMiningNode, MineralVeinRegistry, MineralChunkLifecycleAdapter, and MineralChunkController. No plugin, external package, scene, autoload, Project Settings, or save-schema migration. Existing save payload schema remains unchanged. This is a follow-up to M0.3.27 / PR #442 and preserves M0.3.26 atomic unload.

## Validation

- Focused Controller integration test: godot --headless --path . --script res://tests/mineral_chunk_controller_test.gd.
- Full Compatibility Gate: .github/workflows/godot-validation.yml on the final PR head.
- The new failure test exercises a stale authored timestamp and later participant rejection; the new success test uses a caller-supplied timestamp two minutes behind wall clock and expects exactly two regeneration intervals.
- Local Godot executable is unavailable; GitHub Actions Godot 4.3 headless is the executable validation environment. No test result is claimed until the final-head workflow completes.

## Limitations

The guard protects the mineral-node regeneration and persisted mineral state during Controller chunk loading. It does not make crop, world-object, terrain adjacency, and mineral registration a single cross-system transaction. Object and Resource references outside serialized mineral-node state are not deep-cloned. No GPU, rendered FPS, Xvfb/Mesa, mobile, or target-device validation is claimed.

## Next

After exact-head Focused Controller and Full Compatibility Gate pass, obtain independent review of PR #442. Then investigate aggregate rollback reporting across crops, world objects, terrain adjacency, and minerals; retain full Binder rebuild as the correctness/recovery path until equivalence is proven.
