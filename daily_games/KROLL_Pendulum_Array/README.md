# KROLL Pendulum Array M0.2

A three-chamber physics calibration game built for Godot 4.3+.

## Gameplay
Tune the pendulum length in 0.05 m increments, then run a four-cycle phase test against an amber reference oscillator. Each chamber has a different target period. A successful calibration awards 100 points once per chamber; resetting a cleared chamber cannot farm duplicate score. All three chambers complete the campaign.

The game uses the small-angle pendulum approximation:

`T ≈ 2π√(L/g)`, with `g = 9.81 m/s²`.

## Controls
- Left / Right arrows: shorten or lengthen the pendulum by 0.05 m.
- Enter / Space: run four cycles.
- R: reset the current chamber.
- N: advance after a successful lock.
- On-screen buttons: all actions are also available by mouse and touch.

## Import
- Standalone: open this folder as a Godot project and run `main.tscn`.
- Repository Test Hub: open the root project and choose **KROLL Pendulum Array**; the hub loads `main_root.tscn`.
- No external assets, plugins, network access or audio dependencies.

## Validation
- `tests/rules_test.gd`: period/length inversion, finite bounds, snapping, stage targets and adjacent-step rejection.
- `tests/game_smoke_test.gd`: UI initialization, run/reset, all three successful calibrations, score and campaign restart.
- Local GUI/GPU/device QA is separate from cloud headless validation.
