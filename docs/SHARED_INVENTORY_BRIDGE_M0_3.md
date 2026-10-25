# SurvivalWorldBridge M0.3 — shared instance binding

## Change
- Adds `bind_inventory(shared_inventory)` to inject an already-created inventory instance.
- Checks that the injected object exposes the methods required by the bridge before accepting it.
- `_ready()` only creates a default inventory when no instance has already been bound.

## Why this matters
Previously the bridge always created its own inventory in `_ready()`. If an existing world controller separately owned another inventory object, calling the bridge would create two independent counts and weights. Injection gives the integration layer a way to share one instance.

## Existing-feature compatibility
- Existing prototypes that do not call `bind_inventory()` keep the previous default-inventory behavior.
- This is an integration seam only; it does not yet wire M1.3 `world.gd` to this bridge or replace its legacy `inventory` dictionary.
- Callers must bind the existing instance before the world processes pickups/mining. Godot node lifecycle ordering still needs runtime validation.

## Required tests
1. No injected instance: bridge creates a default inventory.
2. Inject a valid SurvivalInventory before `_ready()`: bridge retains that exact instance.
3. Invalid object missing a required method: binding returns false and current inventory remains unchanged.
4. Collect/drop/mined ore through bridge updates the injected instance and weight summary.
5. Save/load through bridge preserves counts and game day.
6. Existing M1.3 world still behaves unchanged before actual integration.

## Validation
- Source diff reviewed against the current bridge implementation.
- Godot 4 parser, scene startup, and runtime tests have not been run.
