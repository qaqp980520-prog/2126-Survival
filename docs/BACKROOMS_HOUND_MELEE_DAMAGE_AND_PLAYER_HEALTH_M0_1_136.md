# M0.1.136 — Hound Melee Damage and Durable Player Health

## Purpose

Connect the existing Level 2 Hound pursuit loop to a bounded contact-attack driver and a durable player-health model. This is the first production damage path; it deliberately does not add attack animation, knockback, player weapons, or a general combat framework.

## Gameplay contract

- Hound attacks only while its production brain is configured and in the pursue state.
- The player must be within 1.35 m and have a clear world-geometry ray from the Hound's upper body to the player's upper body.
- Each successful attack applies 12 health damage and starts a 1.25 s cooldown.
- Cooldowns are keyed by immutable spawn-cell/entity identity, so transferring a Hound between streamed cells does not reset its cooldown.
- The world-owned driver checks at 10 Hz and processes at most 12 Hounds per tick with a round-robin cursor.
- A defeated player receives no further attacks. The SurfaceWorld HUD reports health and downed state; movement is stopped while downed, while the existing G return and F9 load inputs remain available.
- Health is a 100-point model with validated damage, healing/revival, and schema-1 serialization. Existing saves without the optional backrooms_player.health field load at full health.

## Files

- systems/SurvivalHealth.gd — health, damage, healing/revival, and save validation.
- systems/BackroomsEntityCombatDriver.gd — bounded Hound attack scheduling, cooldowns, range, and world-geometry occlusion.
- world/SurfaceWorld.gd — owns the health and combat models, runs attacks after perception/movement, displays health, and includes health in the combined world envelope.
- tests/survival_health_test.gd — health, invalid-input, healing, defeat, revival, and save/restore tests.
- tests/backrooms_entity_combat_driver_test.gd — Hound pursuit gate, cooldown, wall occlusion, defeated-player gate, and 12-entity round-robin budget.
- tests/surface_world_hound_file_roundtrip_test.gd — verifies health survives the existing production SurfaceWorld/Hound backup-file round trip.
- .github/workflows/godot-validation.yml — adds required test inputs and headless test steps; enables the feature branch in the existing Xvfb/Mesa Hound job.

## Dependencies and import

- Godot 4.3 root project.
- Existing BackroomsEntityBrain, BackroomsPerceptionDriver, BackroomsEntityMovementDriver, BackroomsMazeCellRuntime, and WorldEnvelopeFileStore.
- No external plugins, assets, scenes, autoloads, project settings, or new input actions.
- Root import: godot --headless --path . --editor --import --quit.
- Focused health test: godot --headless --path . --script res://tests/survival_health_test.gd.
- Focused combat test: godot --headless --path . --script res://tests/backrooms_entity_combat_driver_test.gd.
- Existing production persistence test: godot --headless --path . --script res://tests/surface_world_hound_file_roundtrip_test.gd.

## Persistence compatibility

The combined world envelope schema remains version 1. The existing backrooms_player dictionary gains an optional health member with schema_version 1 and a current numeric value. Restore validates this payload before mutating the world. Legacy envelopes without the member load at 100 health. Health is applied only after the surface/session/runtime/lighting/visibility restore succeeds, so a failed world restore does not partially change health.

## Validation status

Pending exact-head GitHub Actions Godot 4.3 validation. No local Godot executable is available. Do not claim runtime, physics, software-rendering, GPU, FPS, or mobile results until the exact candidate HEAD finishes the required workflows and logs are audited.

## Limitations

- Only Hound has an attack path in this version.
- Damage tuning (12 damage, 1.35 m range, 1.25 s cooldown) is a centralized prototype default.
- No attack animation, audio, knockback, weapon system, armour, damage resistance, or medkit/quick-slot health item is included.
- Healing/revival is available through the health model API but is not yet connected to an inventory item.
- No hardware GPU, iPhone/iPad, or device-performance validation is claimed.
