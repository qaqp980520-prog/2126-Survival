# Run 109 — Runtime Inventory Count Snapshot Guard

## Change

The SurvivalInventory counts dictionary remains readable for compatibility, but legacy callers can still mutate it directly. Runtime reads and save serialization now validate values rather than silently truncating fractional values or persisting unregistered keys.

- get_item_count() returns a registered, finite, integer-valued count in the supported range; otherwise it returns zero.
- total_weight_kg() ignores malformed registered counts but retains the one-kilogram fallback for valid directly injected legacy/unregistered counts.
- add_item() and remove_item() reject a malformed existing count instead of coercing it through int().
- to_save_dict() preserves a deep copy of the raw runtime dictionary. The strict loader/save adapter rejects malformed values and unknown keys atomically rather than silently dropping or rewriting data.
- SurvivalWorldBridge.get_item_count() uses the model's validated accessor when available, preserving compatibility with older custom inventory implementations.

## Regression coverage

tests/inventory_weight_boundaries.gd now mutates the public dictionary with fractional, negative and string values. It verifies safe weight calculation, rejected mutations, sanitized save snapshots, unknown-item fallback weight, and bridge reads.

## Import and dependencies

No new dependency. Root Godot 4.3 project; run:

godot --headless --path . --script res://tests/inventory_weight_boundaries.gd

The standalone KROLL Debris Skimmer project is imported separately from daily_games/KROLL_Debris_Skimmer/project.godot.

## Limits

World-save schema remains version 1. The public counts dictionary is retained for backward compatibility; direct external writes are not prevented, but all model read/save boundaries now validate them.
