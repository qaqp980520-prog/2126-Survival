# Run 112 — SurvivalWorldBridge metric validation

## Contract

Custom inventory objects are accepted through the existing method-name contract. The bridge now validates the values returned by its read-only movement/weight methods before exposing them to UI or player systems.

- total_weight_kg: finite numeric value >= 0; invalid values fall back to 0.
- carry_limit_kg: finite numeric value > 0; invalid values fall back to SurvivalInventory.BASE_LIMIT_KG.
- is_overweight and is_super_heavy: only Boolean results are trusted; otherwise derive from validated weight/limit and the default super-heavy threshold.
- movement_multiplier: finite numeric value in [0, 1]; invalid values fall back to 1.0, 0.68 or 0.42 according to validated load state.
- can_jump: only Boolean results are trusted; otherwise derive from the validated super-heavy state.

No public method signature, inventory save payload, or world-save schema changes. World-save schema remains version 1.

## Regression

Run tests/world_bridge_metric_validation_test.gd under Godot 4.3 headless. It exercises NaN, Infinity, strings, negative values, out-of-range movement multipliers, non-Boolean flags, valid custom overrides and public getter consistency.
