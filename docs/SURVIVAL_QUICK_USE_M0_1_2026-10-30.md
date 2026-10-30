# Survival Quick-use Hotbar M0.1 — 2026-10-30

## Scope

Add a four-slot consumable quick-use belt to production SurfaceWorld. SurvivalInventory remains the sole source of item counts and weight; SurvivalStamina remains the sole source of stamina values.

| Slot | Item | Stamina restored |
| --- | --- | ---: |
| 1 | berries | 8 |
| 2 | herbs | 12 |
| 3 | meat | 24 |
| 4 | food | 30 |

Values are prototype tuning. A consumable is removed only when stamina is below maximum. Restoration clamps to remaining capacity; exactly one item is consumed.

## Controls

- Keyboard 1–4 selects a slot.
- C consumes the selected slot.
- Touch quick-use buttons consume the corresponding slot directly.
- Empty slots and full stamina preserve inventory.

## Persistence and compatibility

Optional `quick_use` payload schema 1 stores four assignments and selected slot in the existing world-save envelope without incrementing its schema. Legacy saves without it reset to defaults. Invalid payloads are rejected before player, inventory, stamina or hotbar mutation.

Consumption goes through `SurvivalWorldBridge.consume_item()` so inventory signals remain authoritative. A re-entry guard blocks synchronous nested use; if stamina restoration unexpectedly fails, the model attempts a bridge-based refund and reports rollback status.

## Files

- `systems/SurvivalQuickUse.gd`
- `systems/SurvivalWorldBridge.gd`
- `world/SurfaceWorld.gd`
- `tests/survival_quick_use_test.gd`
- `tests/production_surface_world_quick_use_test.gd`

## Limits / next

Four default consumables are available; slot assignment is currently model-level only, with no drag-and-drop UI. Restoration values are provisional. No local GUI/GPU/iPhone QA is claimed.
