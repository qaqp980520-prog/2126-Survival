# Survival Quick-use Hotbar M0.1 — 2026-10-30

## Scope

Add a four-slot consumable quick-use belt to the production SurfaceWorld. SurvivalInventory remains the sole source of item counts and weight; SurvivalStamina remains the sole source of stamina values.

## Default slot assignments

| Slot | Item | Stamina restored |
| --- | --- | ---: |
| 1 | berries | 8 |
| 2 | herbs | 12 |
| 3 | meat | 24 |
| 4 | food | 30 |

Values are prototype tuning and should be revisited after playable-world feedback. A consumable is only removed when stamina is below maximum. Restoration is clamped to remaining stamina capacity; exactly one item is consumed.

## Controls

- Keyboard 1–4 selects a slot.
- C consumes the selected slot.
- Touch quick-use buttons consume the corresponding slot directly.
- Empty slots and full stamina do not consume inventory.

## Persistence and compatibility

The optional `quick_use` payload has its own schema version 1 and stores four item assignments plus the selected slot. It is embedded in the existing world-save envelope without incrementing that envelope. Legacy saves without the field reset to the default assignments. Invalid payloads are rejected before player, inventory, stamina or hotbar mutation.

## Files

- `systems/SurvivalQuickUse.gd`
- `world/SurfaceWorld.gd`
- `tests/survival_quick_use_test.gd`
- `tests/production_surface_world_quick_use_test.gd`
- `.github/workflows/godot-validation.yml`

## Import and validation

The root Godot project preloads the model through SurfaceWorld. No plugin or external asset is required. The full Godot 4.3 workflow runs the model test and production scene integration test.

## Limits / next

The hotbar currently has four fixed default consumables with assignable slots through the model API; no drag-and-drop inventory UI exists. Consumable restoration amounts are provisional. No local Godot executable is available for GUI/GPU/iPhone QA; rely on exact-head hosted Godot 4.3 CI for engine evidence.
