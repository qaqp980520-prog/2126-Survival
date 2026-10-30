# Survival Stamina Model M0.1 — 2026-10-30

## Scope

This version connects stamina to the production `world/SurfaceWorld.tscn` player. `SurvivalInventory` remains the sole source of carry weight and movement penalties; the stamina model consumes the resulting movement multiplier and does not duplicate inventory rules.

## Prototype balance defaults

| Setting | Default |
|---|---:|
| Maximum stamina | 100 |
| Normal horizontal movement drain | 2.0 per second |
| Idle recovery | 6.0 per second |
| Jump cost | 10.0 |
| Minimum stamina required to jump | 10.0 |

These rates are initial tuning values, not a final balance lock. They are centralized in `systems/SurvivalStamina.gd`.

## Carry-weight coupling

Movement drain is derived from the already-authoritative inventory movement multiplier:

`drain = base_drain / movement_multiplier`

This yields approximately:
- Normal movement (1.00): 2.00 stamina/second.
- Overweight movement (0.68): 2.94 stamina/second.
- Super-heavy movement (0.42): 4.76 stamina/second.

This makes both encumbrance tiers consume more stamina without introducing a second weight calculation.

## Runtime behavior

- Horizontal movement input drains stamina.
- No horizontal movement regenerates stamina.
- A successful jump spends 10 stamina.
- Jumping is denied when stamina is below the jump cost, even if carry weight would otherwise permit jumping.
- Stamina reaching zero does not yet disable walking or add a separate exhaustion speed penalty.

## Save compatibility

- The existing world envelope remains schema version 1.
- Production SurfaceWorld adds an optional `stamina` object with its own schema version 1 and a finite `current` value in the inclusive range 0–100.
- New saves persist current stamina.
- Legacy schema-1 saves without the optional key remain loadable and initialize stamina to full.
- Invalid stamina payloads are rejected before the world-session restore mutates position, inventory, chunks or registries.
- Unknown fields are rejected to keep the payload contract explicit.

## Files and tests

- `systems/SurvivalStamina.gd`
- `world/SurfaceWorld.gd`
- `tests/survival_stamina_test.gd`
- `tests/production_surface_world_stamina_test.gd`
- `.github/workflows/godot-validation.yml`

The model tests cover drain multipliers, recovery, jump cost, bounds and save validation. The production integration test covers carry-weight coupling, save/restore, legacy fallback and non-mutating rejection.

## Known limits and next steps

- Sprinting is not implemented.
- Food/hotbar stamina restoration is not connected; the current production F key remains reserved for crate/mineral interaction.
- GUI, GPU and iPhone hardware acceptance still require a real device.
- Revisit the provisional rates after playable-world feedback; do not silently treat them as final balance.
