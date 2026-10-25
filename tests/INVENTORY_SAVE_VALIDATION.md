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

## Status
These tests have been authored but have **not** been run in Godot 4 in the current environment. A successful GitHub commit is not evidence that the parser or runtime tests pass.
