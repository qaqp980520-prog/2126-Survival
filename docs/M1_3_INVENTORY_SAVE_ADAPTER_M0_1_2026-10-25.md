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

## M1.3.4 source comparison
Static inspection of the available local M1.3.4 prototype confirms the save envelope includes `version`, `inventory`, `game_day`, `stamina`, `selected_hotbar_slot`, `hotbar_slots`, and `world_state`. The inventory dictionary uses eight IDs: `credits`, `meat`, `hide`, `bone`, `berries`, `seeds`, `herbs`, and `food`; all eight are registered in the shared inventory weight table. Hotbar empty-string slots are separate from inventory item IDs. The adapter test now includes a representative fixture with these world fields and asserts that unrelated fields are preserved.

This is a source-level comparison only; it does not prove that the adapter compiles or that the old save implementation is fully compatible at runtime. The actual M1.3.4 world controller is still not on the repository `main` branch, and the adapter is not wired into it.

## Test command
```sh
godot --headless --path . --script res://tests/inventory_save_adapter.gd
```

## Validation status
Authored and statically reviewed only. Godot 4 is not available in the current environment; parser/runtime tests have not been run. Before integration, compare the full M1.3.4 source and real v1/v2 save fixtures, then run the test command and world-save regression suite.
