# Survival Stamina Model M0.2 — 2026-10-30

## Scope

This version adds sprinting and an exhaustion movement penalty to the existing production SurfaceWorld player. SurvivalInventory remains the single source of truth for carry-weight multipliers. Stamina applies a separate movement factor after the inventory multiplier.

## Prototype tuning defaults

| Setting | Default |
|---|---:|
| Maximum stamina | 100 |
| Normal movement drain | 2.0 / second |
| Idle recovery | 6.0 / second |
| Jump cost | 10 |
| Sprint minimum | 5 stamina |
| Sprint speed multiplier | 1.35 |
| Sprint drain multiplier | 2.25 |
| Zero-stamina exhaustion speed multiplier | 0.65 |

These are provisional tuning values, not final balance locks.

## Runtime behavior

- Hold Shift or the on-screen SPRINT button while moving to sprint.
- Sprint increases the stamina movement factor to 1.35 and multiplies movement drain by 2.25.
- Sprint is disabled below 5 stamina to avoid rapid on/off flicker near zero.
- At zero stamina, walking remains possible at 65% of the post-carry movement speed; sprint is unavailable.
- Stationary recovery remains 6 stamina/second. Once current stamina reaches 5, sprint is available again.
- Jump cost and the exact 10-stamina jump boundary are unchanged.
- Carry weight remains authoritative in SurvivalInventory; sprint and exhaustion factors multiply the existing carry movement multiplier rather than replacing it.

## Drain formula

Normal movement: 2.0 / carry_multiplier stamina per second.

Sprint: 2.0 / carry_multiplier * 2.25 stamina per second.

For normal carry weight this is 2.0 while walking and 4.5 while sprinting. At the existing overweight multiplier 0.68, sprint drains about 6.62 per second. At the super-heavy multiplier 0.42, sprint drains about 10.71 per second.

## Save compatibility

The stamina payload still stores only the current value and remains schema 1. No new persistent sprint flag or exhaustion flag is needed because both are derived from the saved current stamina. The world envelope remains schema 1, and legacy saves without the optional stamina payload still initialize stamina to full.

## Files and validation

- systems/SurvivalStamina.gd
- world/SurfaceWorld.gd
- tests/survival_stamina_test.gd
- tests/production_surface_world_stamina_test.gd
- .github/workflows/godot-validation.yml

Tests cover sprint threshold, speed multiplier, sprint drain, exhaustion speed, recovery, touch-button signal, actual production movement profile and carry-weight coupling.

## Known limits

- Sprint and exhaustion rates are provisional and require playable-world feedback.
- Food/hotbar restoration is not connected.
- Sprint does not yet have animation or camera feedback.
- No local Godot GUI, GPU or iPhone hardware test is claimed; exact-head Godot 4.3 CI is the engine validation source.
