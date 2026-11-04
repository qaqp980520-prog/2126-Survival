# Run 113 — SurvivalWorldBridge inventory operation result validation

## Contract

The bridge validates custom inventory mutation return values before emitting item events.

- add_item/remove_item results must be finite whole-number counts in the inclusive range 1..requested.
- When a custom inventory exposes a public Dictionary property named counts, the bridge also compares the reported count with the actual before/after count delta.
- A mismatch is rejected and does not emit item_collected, item_dropped or item_consumed.
- If a mismatched operation did mutate a visible counts dictionary, inventory_changed is emitted so UI listeners can refresh instead of displaying stale data.
- Custom implementations without a public counts Dictionary remain compatible: their sanitized finite whole-number return value is trusted because the bridge has no observable count snapshot. A malformed return triggers a defensive inventory_changed refresh (without an item success event) because the bridge cannot know whether the custom method mutated hidden state.
- Public method signatures and REQUIRED_INVENTORY_METHODS remain unchanged.
- World-save schema remains version 1.

## Regression

Run tests/world_bridge_operation_result_test.gd under Godot 4.3 headless. It covers valid operations, over-reporting, under-reporting, no-op false reports, fractional/string/Boolean results, drop/consume signal behavior, refresh behavior and a method-only custom inventory without a public counts property.


## Run 116 superseding contract — atomic operation verification

Run 116 supersedes the earlier "mismatch remains visible" behavior. Before add/remove, the bridge now captures a detached to_save_dict() snapshot. It accepts an operation only when the reported count, serialized target-item delta and all non-target serialized fields agree. A mismatched mutation is rolled back from the prior snapshot and verified. Verified rollback emits no item event and no misleading refresh; failed or unverifiable rollback emits one defensive inventory_changed signal. Custom inventories without a public counts property remain supported when their serialized snapshot contains an inventory Dictionary. If no valid snapshot baseline exists, the bridge fails closed before invoking the mutation method.

See tests/world_bridge_operation_atomicity_test.gd and docs/README_run116_inventory_operation_atomicity.md for the Run 116 regression contract.
