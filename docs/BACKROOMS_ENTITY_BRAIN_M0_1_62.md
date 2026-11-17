# Backrooms Entity Brain — M0.1.62

## Purpose

M0.1.62 adds a deterministic, perception-driven decision controller to every production Backrooms entity root. It converts a validated perception snapshot into an entity-specific state and behavior intent. It does not perform movement, navigation, animation, combat or perception sensing.

## Files

- `systems/BackroomsEntityBrain.gd` — versioned behavior profiles, input validation, state transitions and target memory.
- `systems/BackroomsMazeCellRuntime.gd` — attaches one `AI` controller to each validated entity root and exposes `submit_entity_perception()`.
- `tests/backrooms_entity_brain_test.gd` — all eight policies, invalid-input atomicity, deterministic decisions, timers and production-runtime gating.
- `tests/backrooms_maze_cell_runtime_test.gd` — updates metadata-only root expectations to require the logic controller while still forbidding renderer nodes.
- `.github/workflows/godot-validation.yml` — includes the new headless contract test in the hardened Full Gate.

## Behavior version 1

| Entity | Initial state | Perception policy | Intent |
| --- | --- | --- | --- |
| Window | dormant | Observe only when a player is visible within 14 m | observe |
| Smiler | dormant | In darkness, approach while unseen; freeze when directly seen | approach / hold |
| Hound | patrol | Strong nearby noise or close sight causes pursuit; moderate noise causes investigation | pursue / investigate / patrol |
| Skin-Stealer | patrol | Close sight causes pursuit; nearby noise causes investigation; farther visible player is shadowed | pursue / investigate / observe |
| Clump | anchored | Enter ambush state only for a visible player within 6 m | hold_ambush |
| Faceling | passive | Avoid a player within 4 m; otherwise remain passive | move_away / remain_passive |
| Duller | passive | Withdraw when a player is within 7 m | withdraw / remain_passive |
| Deathmoth | fly_patrol | Pursue a visible player within 16 m; investigate sound within 22 m | pursue / investigate / aerial_patrol |

All thresholds are explicit profile data. The decision function is deterministic and does not use global random state.

## Runtime contract

- Every production entity root receives an `AI` child configured from the already-validated entity ID, level, cell and world seed.
- Metadata-only/headless roots contain the logic controller but still contain no `Visuals`, MeshInstance3D, physics body or collision geometry.
- `BackroomsMazeCellRuntime.submit_entity_perception(cell_key, entity_id, perception, delta_seconds)` only accepts input while the destination is active.
- The runtime resolves the entity by its owning loaded cell and identity metadata; unloaded entities cannot receive perception.
- Invalid snapshots are rejected without mutating the previous behavior state or target.
- Perception input requires finite non-negative `distance_to_player`; optional `noise_distance` is also finite and non-negative; `noise_strength` is bounded to [0, 1]; line-of-sight/darkness values must be booleans; supplied target vectors must be finite Vector3 values.
- The controller does not poll global scene nodes or run its own process loop. The owning world/perception driver must submit snapshots.

## Test command

```bash
godot --headless --path . --script res://tests/backrooms_entity_brain_test.gd
```

The same test is added to the GitHub Actions Godot 4.3 Full Compatibility Gate with `timeout -k 5s 45s`.

## Dependencies and import

- Depends on `BackroomsEntityDirector.gd` for the authoritative level/entity whitelist.
- Depends on the existing `BackroomsMazeCellRuntime.gd` and production entity-root metadata.
- No new plugin, asset pack, autoload or project setting is required.
- Godot imports the scripts through the existing project; no manual resource import is needed.

## Persistence and limits

- Behavior version 1 is runtime-only. It is deliberately not added to the maze/world save schema because entity decision state is transient and no movement/AI state persistence contract exists yet.
- Cell unload/rebuild resets the brain to its entity-specific initial state.
- The current controller emits intents and remembers the last valid target position; it does not move entities.
- No automatic player distance, line-of-sight, darkness or sound sensor is wired yet.
- Collision, NavigationAgent3D, pathfinding, steering, animation, perception sensors, combat, damage and audio remain out of scope.
- Mesa graphical coverage from M0.1.61 remains software-renderer coverage, not hardware GPU or iPhone validation.

## Next step

Add a bounded perception driver owned by SurfaceWorld, then connect movement/collision and per-entity navigation without changing the deterministic spawn or visual-factory contracts.
