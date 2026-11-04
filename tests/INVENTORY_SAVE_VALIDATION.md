# SurvivalInventory save-validation smoke tests

## Run
From the repository root with Godot 4 installed:

```sh
godot --headless --path . --script res://tests/inventory_save_validation.gd
```

## Coverage
- Valid save/load round trip and defaults for registered items omitted from a save.
- Reject fractional item counts without changing the current inventory.
- Reject unsupported schema versions and unregistered item IDs.
- Reject invalid game-day values without changing the current inventory.
- Reject unregistered items in runtime add/remove operations.
- Run 109 additionally verifies malformed registered runtime values are ignored by weight/count reads and serialized as zero, while unknown keys remain visible so strict save validation rejects them without mutating live state.

## Status
The test is executed by the Godot 4.3 GitHub headless validation workflow. Local GUI/GPU testing is a separate acceptance task.
