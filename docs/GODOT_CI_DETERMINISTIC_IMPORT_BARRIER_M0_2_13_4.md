# Godot CI Deterministic Root Import Barrier — M0.2.13.4

## Finding

The exact-head Full Godot 4.3 run for PR #312 stopped in the Backrooms Portal Playground integration test before reaching the mineral streaming regressions. The log showed:

- `SCRIPT ERROR: Preload file "res://assets/textures/backrooms_wallpaper.svg" has no resource loaders`
- `Failed to load script "res://prototypes/BackroomsPortalPlayground.gd"`
- The subsequent missing `get_current_level` call and watchdog timeout were downstream symptoms of that script parse failure.
- The preceding root import command was `godot --headless --path . --editor --quit`; its log included `Scan thread aborted...`.

The import command quit after the first editor iteration and did not guarantee that all project resources had finished importing before the next headless test process started. This made the SVG preload test sensitive to import completion timing.

## Correction

Replace the root-project import command in both workflows with:

```bash
godot --headless --path . --import
```

Godot 4.3 documents `--import` as starting the editor, waiting for resources to be imported, and then quitting; it implies `--editor` and `--quit`.

Updated workflows:

- `.github/workflows/godot-validation.yml`
- `.github/workflows/mineral-grid-streaming-lifecycle-validation.yml`

Both workflows now contain source guards requiring the deterministic root import command. The lifecycle workflow also watches this document so future edits rerun the relevant validation.

## Dependencies / import

- Godot 4.3 editor build from the existing CI container `barichello/godot-ci:4.3`.
- No runtime script, asset bytes, scene wiring, project settings, or save schema changed.
- No external package or manual import is required.

## Validation status

- The failing exact-head full gate was [Run #42919572303](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/42919572303), which stopped at the Backrooms Portal Playground integration step with the SVG import failure above. It is not a pass.
- The Director focused, Mineral Grid Streaming Lifecycle, and Production Benchmark workflows on the same PR #312 head succeeded before this CI correction.
- The updated workflow commands and source guards are committed to the PR #312 branch. A new exact-head full gate must complete before any full compatibility pass is claimed.
- No local Godot executable is available; validation must use exact-head Godot 4.3 CI.

## Limitations

- This change makes the root resource import barrier deterministic; it does not repair or modify the Backrooms runtime itself.
- Headless CI still does not validate rendered FPS, GPU, iPhone, device memory, or touch behavior.
- PR #312 remains Draft and unmerged pending the new exact-head full gate and independent parent-chain review.

## Next step

Verify that the new exact-head Full Godot 4.3 run completes the root import step without a scan-thread abort and then passes the Backrooms Portal Playground integration test. Confirm all 553 steps and cleanup steps succeed.