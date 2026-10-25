# M1.3 Inventory Save Adapter｜Prototype M0.3｜2026-10-25

## Purpose
Introduce a narrow, testable conversion boundary between the legacy M1.3 world-save envelope and the shared `SurvivalInventory` payload. This is a standalone prototype and is not connected to the active world controller.

## Files
- `systems/SurvivalInventorySaveAdapter.gd`
- `tests/inventory_save_adapter.gd`

## Behavior
- Accepts legacy world save versions 1 and 2. Numeric integer-valued versions such as `2.0` remain accepted to match the legacy validator's numeric-to-integer cast.
- Converts the top-level `inventory` dictionary and `game_day` into shared inventory schema version 1.
- Independently validates the adapter boundary before calling the shared model: schema version must be 1; game day and counts must be finite integers in range; item IDs must be strings registered in `SurvivalInventory.ITEM_WEIGHTS`.
- Uses limits of 1,000,000,000 per item count and game day to avoid unbounded values.
- Unknown item IDs fail closed. The legacy M1.3 loader only copied registered IDs and effectively ignored unknown keys; the adapter intentionally does not silently discard them. If future or modded saves contain extra item IDs, add an explicit migration/registry mapping before integration.
- Fractional counts/game days and values over the new limits fail closed. The legacy validator accepted fractional game days by truncating them later and had a much looser numeric bound; this adapter intentionally rejects those ambiguous values rather than silently changing them.
- Applying a valid shared inventory payload duplicates the full world-save dictionary and replaces only `inventory` and `game_day`, preserving unrelated world fields.
- Returns `{ok: false, error: ...}` on failure and never mutates the supplied world-save dictionary.

## M1.3.4 source comparison
Direct inspection of `scripts/world.gd` in the available M1.3.4 prototype shows the actual save keys are `version`, `inventory`, `game_day`, `stamina`, `hotbar_slots`, `selected_hotbar`, `player_position`, and `world_state`. Note the field is `selected_hotbar`, not `selected_hotbar_slot`. The inventory dictionary uses eight IDs: `credits`, `meat`, `hide`, `bone`, `berries`, `seeds`, `herbs`, and `food`; all eight are registered in the shared inventory weight table. The updated test fixture now uses the real field names and asserts preservation of player position, stamina, hotbar, and world state.

## Important dependency finding
The current `main` version of `SurvivalInventory.load_save_dict()` does not itself validate `schema_version`, fractional values, known item IDs, or upper bounds. Therefore the adapter now performs strict validation independently before calling that model. Do not assume the adapter is protected by the inventory model alone. The separate inventory validation PR remains unmerged and untested.

## Test command
```sh
godot --headless --path . --script res://tests/inventory_save_adapter.gd
```

## Validation status
Authored and statically reviewed only. Godot 4 is not available in the current environment; parser/runtime tests have not been run. This change is not integrated into the world controller. Before integration, run the adapter tests, inventory-model tests, and world-save regression suite against actual v1/v2 fixtures.
