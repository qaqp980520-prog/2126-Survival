# SurvivalWorldBridge restore read-isolation guard M0.1

- Source: systems/SurvivalWorldBridge.gd
- Regression: tests/world_bridge_restore_read_isolation_test.gd
- Problem: a custom inventory can call Bridge serialization/read methods from inside load_save_dict() after partially mutating its own state. Without a guard, an intermediate snapshot or metrics could escape.
- Policy while _inventory_restore_in_progress is true:
  - serialize_inventory() returns {ok:false,error:inventory_restore_in_progress}.
  - serialize_world_save() returns the same explicit error.
  - get_item_count() returns 0.
  - get_summary()/weight/movement/jump metric reads return safe default metrics.
  - Normal serialization and reads resume after the transaction releases its lock.
- The regression verifies no extra to_save_dict() call occurs during the callback, no partial value escapes, and inventory_changed listeners can serialize the completed snapshot after lock release.
- Public method signatures and world-save schema 1 remain unchanged.
- Limitation: direct references held by third-party code can still mutate custom inventory fields outside the bridge; the guard applies to Bridge-mediated reads and operations.
- Follow-up to GitHub issue #266.
