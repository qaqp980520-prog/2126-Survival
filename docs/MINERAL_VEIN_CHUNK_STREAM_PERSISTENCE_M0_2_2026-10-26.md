# Mineral Vein Registry — Streamed Chunk Persistence M0.2

Date: 2026-10-26

## Purpose

Extend the stable-ID mineral registry so a vein remains represented in world-save data after its streamed chunk unloads. A stable ID is no longer required to have a live MineralMiningNode at save/restore time.

## Changes

- systems/MineralVeinRegistry.gd
  - Keep _saved_records separately from _veins (live nodes).
  - unregister_vein(stable_id, expected_vein, now_unix) advances regeneration to the unload time, captures the node record, then removes only the live reference.
  - to_save_dict() serializes both loaded and unloaded IDs in sorted order.
  - restore_save_dict() validates the entire incoming record map before applying it; valid unloaded IDs are retained for later registration.
  - register_vein(stable_id, node, now_unix) restores an existing saved record before exposing the new live node and applies offline regeneration according to auto_apply_elapsed_time_on_restore.
  - Add get_saved_ids() to distinguish all persisted IDs from currently loaded IDs returned by get_registered_ids().
  - Re-registering the exact same live node is idempotent; it never reapplies a stale cached record to a node that has changed since registration.

- tests/mineral_catalog_test.gd
  - Update the old unknown-ID expectation: a valid record for an unloaded stable ID is now intentionally accepted and retained.
  - Add unload → serialize → free node → re-create node → register same stable ID → elapsed regeneration regression coverage.
  - Assert invalid restore data does not mutate a live vein or the saved record.

## Compatibility and dependencies

- Godot 4.3+.
- Uses existing systems/MineralMiningNode.gd and systems/MineralCatalog.gd; no plugin or external asset dependency.
- Existing register_vein(id, node), unregister_vein(id, node), get_registered_ids(), to_save_dict(), and restore_save_dict(data, now) calls remain source-compatible. New clock arguments are optional.
- Registry envelope remains schema version 1; individual mineral node records continue to use the existing schema-v2 format and legacy schema-v1 loading.

## Import and test

1. Open the repository root (the folder containing project.godot) in Godot 4.3+.
2. Import the project.
3. Run the shared CI command from repository root:

   godot --headless --path . --script res://tests/mineral_catalog_test.gd

The shared workflow must also reject SCRIPT ERROR, ERROR:, or FAIL: output and require the explicit mineral regression success marker. A successful local/static inspection alone is not engine-test evidence.

## Limits

- The formal world/chunk streaming controller is not present in the repository, so its unload/load lifecycle still needs to call unregister_vein() and register_vein() using deterministic chunk-local IDs.
- restore_save_dict() treats its input as the world registry snapshot: previously unloaded records omitted from the snapshot are discarded, while live nodes omitted from it are preserved as newly existing nodes.
- This headless regression validates persistence and gameplay state, not mesh/VFX appearance or iPhone playability.

## Validation status

Pending the Godot 4.3 CI run for the current PR head. Do not merge this change unless the complete shared regression succeeds and guarded logs are clean.
