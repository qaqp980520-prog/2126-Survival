# M1.3 Inventory Save Adapter｜Prototype M0.1｜2026-10-25

## Purpose
Introduce a narrow, testable conversion boundary between the legacy M1.3 world-save envelope and the shared `SurvivalInventory` payload. This is a standalone prototype and is not connected to the active world controller.

## Files
- `systems/SurvivalInventorySaveAdapter.gd`
- `tests/inventory_save_adapter.gd`

## Behavior
- Accepts legacy world save versions 1 and 2 only.
- Converts the top-level `inventory` dictionary and `game_day` into the shared inventory schema.
- Validates all item IDs and counts through `SurvivalInventory.load_save_dict()`; unknown IDs and malformed counts fail closed.
- When applying a valid shared inventory payload, duplicates the full world-save dictionary and replaces only `inventory` and `game_day`, preserving unrelated world fields.
- Returns `{ok: false, error: ...}` on failure and never mutates the supplied world-save dictionary.

## Test command
```sh
godot --headless --path . --script res://tests/inventory_save_adapter.gd
```

## Validation status
Authored and statically reviewed only. Godot 4 is not available in the current environment; parser/runtime tests have not been run. This is not yet integrated with M1.3's actual world controller. Before integration, confirm that the real v1/v2 world save uses the expected `version`, `game_day`, and `inventory` keys and that all legacy item IDs are registered in `ITEM_WEIGHTS`.
