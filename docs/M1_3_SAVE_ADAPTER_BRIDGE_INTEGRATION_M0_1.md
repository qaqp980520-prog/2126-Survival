# M1.3 Save Adapter Bridge Integration M0.1 — 2026-10-26

## What changed

- The shared SurvivalWorldBridge now uses SurvivalInventorySaveAdapter for full world-save envelope conversion.
- Added serialize_world_save(existing_world_save), which updates inventory and game_day while preserving unrelated legacy fields.
- Added restore_world_save(world_save), which validates the legacy envelope before applying the inventory payload; failed restores do not mutate the live inventory.
- Kept serialize_inventory/restore_inventory unchanged for callers that use the inventory-only schema.
- Added a Godot headless integration test for real M1.3-like fields: stamina, hotbar slots, selected slot, player position, crops, world seed, and world state.

## Dependencies and use

- Godot 4.3+.
- systems/SurvivalInventory.gd, systems/SurvivalInventorySaveAdapter.gd, and systems/SurvivalWorldBridge.gd.
- The adapter supports legacy world-save versions 1 and 2; item IDs must be registered in SurvivalInventory.ITEM_WEIGHTS.
- The active M1.3 world controller is still not present in the repository, so this integrates the adapter with the reusable bridge API rather than claiming the production controller is wired.

## Validation

Godot 4.3 CI run #24 passed on 2026-10-25T23:18:11Z (UTC), including all existing Signal Sweep, Orbital Convoy, portal, inventory validation, and adapter tests plus the new bridge integration test. The local environment has no Godot executable; the engine-level evidence comes from CI, not a local run.

## Known limits

- No automatic world.gd migration; callers must opt into serialize_world_save/restore_world_save.
- World-save schema versions outside 1/2 are rejected.
- Unknown or malformed item counts are rejected atomically.
- This bridge-level integration does not test actual 3D scene load/save or iPhone behavior.
