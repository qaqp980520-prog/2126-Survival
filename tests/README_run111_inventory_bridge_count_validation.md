# Run 111 — SurvivalWorldBridge custom inventory count validation

## Problem

The built-in SurvivalInventory validates counts as finite, non-negative, whole numeric values within MAX_SAVED_COUNT. The world bridge also accepts custom RefCounted inventory implementations. Its legacy dictionary fallback previously accepted only positive integers, so an integral float such as 3.0 behaved differently from the built-in model. The custom get_item_count path also trusted the returned value without applying the shared count boundary.

## Change

- Route both custom get_item_count results and legacy counts-dictionary fallback values through one bridge validator.
- Accept integer and whole-valued float counts from zero through SurvivalInventory.MAX_SAVED_COUNT.
- Reject fractional, negative, non-finite, non-numeric, boolean and out-of-range values.
- Preserve the legacy behavior of reading positive counts for unknown keys from custom inventory dictionaries; strict save validation remains responsible for rejecting unknown item IDs.

## Files

- systems/SurvivalWorldBridge.gd
- tests/helpers/LegacyInventoryCountFixture.gd
- tests/helpers/MethodInventoryCountFixture.gd
- tests/world_bridge_legacy_inventory_count_test.gd

## Compatibility

- No public method signature changes.
- No inventory schema or world-save schema change; schema remains 1.
- Existing custom inventories still need the established REQUIRED_INVENTORY_METHODS contract.
- Local Godot GUI/GPU and physical iPhone QA are separate from headless validation.

## Validation

The dedicated Run 111 focused workflow and the full Godot Compatibility Gate import the root project and run this regression with Godot 4.3.
