# Backrooms Lighting Profile and Darkness Sampling — M0.1.64

## Summary

Add deterministic level-specific Backrooms lighting profiles, per-cell ceiling-light placement, a transactional WorldEnvironment override, and a local darkness sampler consumed by the bounded perception driver. Level 1 now has deterministic lit and unlit pockets, allowing Smiler's existing darkness policy to activate only where the sampled cell is actually dark.

## Files

- `systems/BackroomsLightingProfile.gd` — Level 0–5 ambient/local light profiles, deterministic cell-light descriptors, and local illumination sampling.
- `systems/BackroomsLightingController.gd` — Transactional WorldEnvironment clone/swap and exact restoration of the SurfaceWorld environment and sun.
- `systems/BackroomsMazeCellRuntime.gd` — Attaches a profile-driven OmniLight3D to selected cell roots and stores the shared descriptor in metadata.
- `systems/BackroomsPerceptionDriver.gd` — Samples darkness from the owning cell's light descriptor/live light instead of always accepting the SurfaceWorld fallback.
- `world/SurfaceWorld.gd` — Applies the Backrooms environment after a committed entry, restores the SurfaceWorld environment on return, and derives the same level profile after combined-world-save restore.
- `tests/backrooms_lighting_test.gd` — Profile coverage, deterministic placement, lit/dark sampling, invalid-level rejection, and environment transaction rollback.
- `tests/backrooms_combined_world_save_test.gd` — Entry/return and save-restore lighting regression assertions.
- `.github/workflows/godot-validation.yml` — File-presence and bounded lighting test steps.
- `docs/BACKROOMS_LIGHTING_M0_1_64.md` — This version record.

## Dependencies and import

Godot 4.3 only. No plugins, autoloads, external assets or manual import steps. SurfaceWorld preloads the controller; the controller and cell runtime preload the shared profile script.

## Lighting behavior

- SurfaceWorld's original Environment resource and KrollSun energy/visibility are captured without mutation.
- Backrooms entry duplicates the Environment, applies the destination level's ambient/background/exposure values, and sets KrollSun energy to zero.
- Each graphical maze cell may receive one ceiling OmniLight3D according to a deterministic function of level, cell coordinates and world seed.
- The same per-cell descriptor drives the actual light and the darkness sampler.
- Level 1 has alternating lit and unlit cells; Smiler receives `is_dark=true` only in unlit pockets or outside the local light's effective radius.
- Returning to the surface restores the original Environment object and exact sun energy/visibility.
- Combined world-save restore derives the profile from the restored LocationSession; lighting is not separately serialized because it is deterministic from the level.

## Test command

```bash
godot --headless --path . --script res://tests/backrooms_lighting_test.gd
```

CI runs this under the existing hard-kill wrapper and strict diagnostic/success-marker checks.

## Limitations

- Local-light placement is deterministic and per-cell; there is not yet dynamic flicker, switchable light gameplay, battery consumption, or a full physically based luminance probe.
- The darkness sampler uses the same authored light descriptor and live OmniLight3D state with a distance attenuation approximation; it is not a renderer readback.
- Hardware GPU, mobile renderer, iPhone, and real-device performance remain untested.
- No navigation, entity movement, collision, combat, damage or audio is added in this version.

## Next steps

1. Validate exact-head Godot 4.3 Full Gate and complete logs.
2. Integrate this PR into the perception-driver parent only after independent review, then rerun the parent exact-head gate.
3. Add bounded entity movement/navigation after darkness perception is stable.
