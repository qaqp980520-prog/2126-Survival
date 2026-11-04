# Run 117 system note — successful restore verification

## Problem

SurvivalWorldBridge._restore_inventory_atomically() previously treated a custom inventory's boolean `true` return from `load_save_dict()` as proof that the requested payload had been applied. A custom implementation could return true while doing nothing or serializing a different state; the bridge would emit inventory_changed and report success.

## Change

- Capture the pre-restore snapshot as before.
- Build an expected serialized snapshot from the requested payload.
- Normalize integer-valued schema/day/count values to integers.
- For the built-in SurvivalInventory only, fill omitted known item IDs with zero because its canonical serializer always emits the complete ITEM_WEIGHTS key set.
- Require the post-load to_save_dict() result to exactly equal the expected snapshot before returning success.
- If the loader returns false, returns a non-boolean, returns true with a no-op, or returns true with mismatched serialized data, attempt rollback and verify the original snapshot.
- Emit a defensive inventory_changed refresh only when rollback cannot be verified.

## Compatibility

- Public SurvivalWorldBridge signatures and REQUIRED_INVENTORY_METHODS are unchanged.
- World-save schema remains 1.
- Built-in SurvivalInventory compact payload restore remains supported.
- Custom inventories must serialize the complete state they expect the bridge to verify; opaque state omitted from to_save_dict() cannot be validated.

## Regression

`tests/world_bridge_restore_success_verification_test.gd` covers lying success, no-op success, unverifiable rollback, normal custom restore, built-in compact restore and world-save restore.

## Validation

Godot 4.3 focused and full CI are run on the exact PR head. Local GUI/GPU and physical iPhone QA are not claimed.


## New game

KROLL Thermal Containment Lab M0.1 is a 4×4 deterministic heat-diffusion puzzle with three chambers, four vent cycles per chamber, a unique four-row vent schedule, undo/restart and a one-time 300-point campaign ledger. See `daily_games/KROLL_Thermal_Containment_Lab/README.md` for controls and rules.