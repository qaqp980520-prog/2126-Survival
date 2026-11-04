# Run 116 — SurvivalWorldBridge inventory operation atomicity

## Contract

Before invoking a custom inventory add_item() or remove_item(), SurvivalWorldBridge captures a detached to_save_dict() snapshot. The snapshot must be a Dictionary containing an inventory Dictionary with a valid whole-number count for the target item. If a safe baseline cannot be captured, the bridge fails closed before calling the mutator.

After the operation, the bridge reads a second serialized snapshot and accepts the operation only when:

- The method result is a finite whole-number count in the range 1..requested.
- The target item's serialized count delta exactly matches the reported count and requested direction.
- Every non-target serialized field is unchanged.

If a mutator changes data but reports an invalid or inconsistent result, the bridge attempts to restore the pre-operation snapshot through load_save_dict(), then verifies the complete serialized snapshot. A verified rollback returns failure without item success events or an unnecessary inventory_changed signal. If rollback cannot be verified, the bridge returns failure and emits one defensive inventory_changed signal so observers do not display a known-stale snapshot.

## Compatibility

- Public SurvivalWorldBridge method signatures are unchanged.
- REQUIRED_INVENTORY_METHODS is unchanged.
- World-save schema remains version 1.
- Built-in SurvivalInventory remains compatible.
- Custom inventories without a public counts property remain supported when to_save_dict() exposes the standard inventory Dictionary.
- Custom inventories with opaque state omitted from to_save_dict(), invalid snapshots, or broken rollback implementations cannot receive an atomicity guarantee; the bridge fails closed before mutation when the initial snapshot is invalid and reports/refreshes when rollback cannot be verified.

## Regression coverage

Run tests/world_bridge_operation_atomicity_test.gd under Godot 4.3 headless. It covers valid add/remove, under/over-reporting, fractional/string/Boolean results, collateral mutation of unrelated items, no-op positive reports, verified rollback, failed rollback, event suppression, defensive refresh, and method-only custom inventories.

## Validation

Target engine: Godot 4.3 headless CI. Local GUI/GPU and physical iPhone QA are not claimed.
