# Run 115 — World bridge serialization snapshot isolation

## Contract

SurvivalWorldBridge.serialize_inventory() returns a deep copy of the custom inventory's serialized Dictionary. A caller can inspect or mutate the returned snapshot without obtaining a reference to the inventory's live nested data.

serialize_world_save() reads the custom snapshot once, rejects a non-Dictionary result with invalid_inventory_snapshot, deep-copies a valid Dictionary, then passes that detached snapshot to SurvivalInventorySaveAdapter. The adapter remains responsible for strict schema, item-ID, count and day validation.

## Regression coverage

tests/world_bridge_serialization_snapshot_test.gd uses a custom inventory whose to_save_dict() deliberately exposes its live counts Dictionary. The test mutates the bridge snapshot and exported world envelope and verifies the live inventory and caller's original world envelope remain unchanged. It also checks non-Dictionary snapshots and raw invalid Dictionary payloads.

## Compatibility

- Public bridge method signatures unchanged.
- REQUIRED_INVENTORY_METHODS unchanged.
- World-save schema remains 1.
- Built-in SurvivalInventory remains compatible.
- No new dependency or Test Hub registration.

## Limitation

A Dictionary snapshot with invalid contents is intentionally returned as a detached raw copy by serialize_inventory() so strict downstream validation can reject it rather than silently rewriting data. serialize_world_save() returns the save adapter's validation error. A custom inventory returning a non-Dictionary snapshot yields an empty Dictionary from the legacy Dictionary-returning serialize_inventory() API and a precise error from world-save export.

## Validation

Target engine: Godot 4.3 headless CI. Local GUI/GPU and physical iPhone QA are not claimed.
