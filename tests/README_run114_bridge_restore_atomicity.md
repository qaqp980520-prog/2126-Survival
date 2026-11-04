# Run 114 — World bridge restore atomicity

## Contract

Both restore_inventory() and restore_world_save() now capture the custom inventory's serialized state before invoking load_save_dict(). If the custom loader returns false or a non-Boolean result after mutating state, the bridge attempts to load the captured snapshot and verifies the serialized state matches it exactly.

- Verified rollback: return false and do not emit inventory_changed, because observers still see the original state.
- Failed or unverifiable rollback: return false and emit inventory_changed so UI observers refresh from the state that actually remains.
- Successful restore: return true and emit one inventory_changed signal.
- Missing or invalid pre-restore snapshot: reject before invoking the custom loader.
- Invalid world-save envelopes are rejected by SurvivalInventorySaveAdapter before the custom loader runs.

## Regression coverage

tests/world_bridge_restore_atomicity_test.gd covers partial mutation followed by false, exact rollback, world-save rollback, rollback failure, a loader that claims rollback success but restores the wrong snapshot, invalid snapshot rejection, invalid world-save rejection and successful restore notification.

## Compatibility and limitation

Public bridge method signatures, REQUIRED_INVENTORY_METHODS and world-save schema 1 remain unchanged. Built-in SurvivalInventory already validates atomically; this bridge-level protection covers custom inventory implementations that honor the existing serialization contract.

Rollback is best-effort for arbitrary custom implementations. If to_save_dict() omits hidden mutable state, or load_save_dict() refuses/incorrectly reports rollback, the bridge cannot guarantee restoration; it reports failure and emits a defensive inventory_changed refresh instead of claiming atomic success.

## Validation

Target engine: Godot 4.3 headless CI. Local GUI/GPU and physical iPhone QA are not claimed.
