# Run 105 — crop state through queued-root recovery

## Scope

Extend the Run 104 queued-root recovery regression to the crop subsystem. A real CropPlotVisual is registered by MineralChunkController, a stable-ID wheat crop is planted and advanced, then its owning chunk root is externally queued for deletion. The production MineralGridStreamingDirector requests the same coordinate again.

## Expected behavior

- Queued root and crop plot disappear from live crop enumeration.
- Same-coordinate sync runs the normal controller unload/replacement path.
- The replacement CropPlotVisual is a new node but retains the exact stable crop ID.
- CropRegistry remains the source of truth; reload catches the crop up from the last timestamp to the supplied reload time.
- The test checks growth stage, progress, moisture, timestamp and visual refresh.
- Repeating the same timestamp is idempotent.
- Old root and plot weak references clear after the frame.

## Run

From repository root with Godot 4.3+:

    godot --headless --path . --script res://tests/mineral_grid_streaming_queued_root_crop_recovery_test.gd

No world-save schema change, external assets, plugins or network dependencies. This is headless integration coverage; local rendered GUI/GPU and physical iPhone QA remain separate.
