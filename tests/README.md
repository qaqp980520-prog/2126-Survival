# Shared inventory bridge smoke tests

## Run
From the repository root in a Godot 4 environment:

```sh
godot --headless --path . --script res://tests/shared_inventory_bridge_smoke.gd
```

Use `godot4` instead of `godot` if that is the executable name on your system.

## Coverage
- Binds a valid inventory instance before the bridge enters the scene tree.
- Rejects an object missing required methods without replacing the valid inventory.
- Confirms `_ready()` preserves the injected instance.
- Confirms world pickup, mined ore and dropping all mutate the same counts.
- Checks save/load round-trip through the inventory serialization API.

## Status
The test script is committed but has not been executed in this environment because a Godot 4 executable is not available here. A committed test is not evidence that the test passed.
