# Shared Inventory M0.2.1 — validation hardening

## Change
- Unknown item IDs now use a conservative 1.0 kg default weight instead of silently weighing 0 kg. Explicitly registered items such as credits retain their configured weight.
- Save loading validates schema_version == 1, positive integer game_day, non-empty string item IDs, and finite non-negative integer item counts.
- Validation completes before live state is mutated, so malformed payloads do not partially overwrite the current inventory.

## Integration impact
- SurvivalWorldBridge can still collect arbitrary non-empty item IDs; unknown IDs now count toward carry weight rather than becoming weightless.
- Existing registered weights are unchanged.
- Existing save payloads from to_save_dict() include schema_version 1 and should satisfy the schema, but still require Godot 4 tests.
- This module is not yet wired into M1.3 world.gd, so this change does not solve the duplicate-inventory source-of-truth risk.

## Validation status
- Source diff reviewed against current main implementation.
- Godot 4 parser/runtime tests not run; no confirmed Godot 4 executable is available in this environment.
- Required tests: known item weights, unknown item fallback, malformed schema version, negative/fractional/huge counts, repeated load, failed load leaves previous counts/day unchanged.