# M0.1.137 — Explicit Hound Target-Source Combat Gate

## Purpose

Close a false-positive melee-damage path in M0.1.136: a Hound could be in the `pursue` state for a non-player noise, and if that noise position happened to be within 2.5 m of the player, the combat driver could interpret proximity as proof that the Hound was pursuing the player.

## Gameplay and compatibility contract

- `BackroomsEntityBrain` exposes `target_source` in its runtime snapshot and save payload: `player`, `noise`, or `none`.
- A visible-player pursuit explicitly targets the player, even when player movement noise is also present.
- Noise-driven `pursue` and `investigate` snapshots explicitly target noise.
- `BackroomsEntityCombatDriver` applies melee damage only when the brain is configured, in `pursue`, and `target_source == "player"`; target-position proximity alone is not authorization.
- A noise point within 2.5 m of the player cannot cause a false melee hit.
- Older brain save payloads without `target_source` remain loadable. Their ambiguous retained target is cleared until the next perception sample, so legacy data fails closed for combat.
- New noise-pursuit saves preserve both `target_source == "noise"` and the `pursue_sound` intent across round-trip.

## Files

- `systems/BackroomsEntityBrain.gd` — explicit target-source selection, snapshot and save compatibility.
- `systems/BackroomsEntityCombatDriver.gd` — player-target-only melee gate.
- `tests/backrooms_entity_brain_test.gd` — player/noise source, new save round-trip, and legacy fail-closed restore.
- `tests/backrooms_entity_combat_driver_test.gd` — co-located unrelated-noise regression and positive player-target control.
- `docs/BACKROOMS_HOUND_MELEE_DAMAGE_AND_PLAYER_HEALTH_M0_1_136.md` — parent gameplay contract and limitations.
- `docs/BACKROOMS_HOUND_TARGET_SOURCE_COMBAT_GATE_M0_1_137.md` — this version record.

## Dependencies and import

- Godot 4.3 root project.
- Existing `BackroomsEntityBrain`, `BackroomsPerceptionDriver`, `BackroomsEntityMovementDriver`, `BackroomsMazeCellRuntime`, `BackroomsEntityOwnershipLedger`, `BackroomsEntityCombatDriver`, and `SurvivalHealth`.
- No external plugin, asset, scene, autoload, project setting, or input action.
- Root import: `godot --headless --path . --editor --import --quit`.
- Brain regression: `godot --headless --path . --script res://tests/backrooms_entity_brain_test.gd`.
- Combat regression: `godot --headless --path . --script res://tests/backrooms_entity_combat_driver_test.gd`.

## Validation status

Pending exact-head GitHub Actions validation after this documentation commit. The preceding code-only candidate is not treated as evidence for this final documentation-bearing HEAD. No local Godot executable is available.

## Limitations

- Only Hound currently has a damage path.
- No attack animation/audio, knockback, armour, weapons, damage resistance, or medkit/quick-slot health item.
- Healing/revival remains an API and is not connected to inventory.
- Hound attack cooldowns are session-local and are not persisted.
- No hardware GPU, FPS, or mobile-device validation is claimed.

## Next step

Complete and audit all exact-head Godot 4.3 workflows, then update the final observed CI evidence in the PR, Notion asset index, long-term project page, and daily work record. Keep the PR stacked on its validated parent; do not merge independently of the parent chain.
