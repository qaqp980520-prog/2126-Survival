# Run 118 — SurvivalWorldBridge restore reentrancy guard

## Problem

A custom inventory's load_save_dict() executes user-defined code. During restore it could call back into the bridge to start a nested restore, collect/drop an item, or bind a replacement inventory. The outer restore would then continue against a state that had been modified by reentrant bridge operations.

## Change

- Add _inventory_restore_in_progress as a transaction guard.
- Replace public inventory storage with a guarded property backed by _inventory; direct property assignment is rejected while restore is active and invalid inventory contracts are rejected at assignment.
- bind_inventory() refuses replacement while a restore transaction is active.
- _apply_inventory_operation() refuses collect/drop/consume mutations during restore callbacks.
- Nested restore_inventory() and restore_world_save() calls are rejected by the same guard.
- Separate _perform_inventory_restore() from the transaction wrapper so the lock is always released before inventory_changed is emitted. Signal listeners may safely react after the transaction finishes.

## Compatibility

- Public method names and signatures are unchanged.
- REQUIRED_INVENTORY_METHODS is unchanged.
- World-save schema remains 1.
- Built-in SurvivalInventory remains compatible.
- The lock covers bridge-mediated operations and the public inventory property; arbitrary direct mutation of a custom inventory's own fields cannot be prevented by the bridge.

## Regression

tests/world_bridge_restore_reentrancy_test.gd uses a custom loader that attempts nested restore, collect, bind_inventory() replacement and direct property assignment from inside load_save_dict(). The outer restore must succeed with only its requested snapshot applied, while all nested bridge mutations and replacement attempts are rejected. Existing Run 117 restore-success and rollback regressions remain in the full compatibility gate.

## Validation

Target engine: Godot 4.3 headless CI. Local rendered GUI/GPU and physical iPhone QA are not claimed.
