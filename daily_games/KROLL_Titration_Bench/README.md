# KROLL Titration Bench M0.1

A playable chemistry-lab timing game for Godot 4.3+. Titrate three simulated monoprotic strong-acid samples with a known 0.100 M base, read the live pH curve and lock the endpoint within 0.5 mL.

## Model

Each sample contains 25.0 mL of an unknown strong acid. The simulated titrant is 0.100 M NaOH. Sample concentrations are authored as 0.080 M, 0.120 M and 0.160 M, giving reference equivalence volumes of 20.0 mL, 30.0 mL and 40.0 mL.

Before equivalence, pH is calculated from excess hydrogen-ion moles divided by total volume. At equivalence the simplified strong-acid/strong-base model returns pH 7.00. After equivalence, pH is calculated from excess hydroxide. This is an educational ideal-solution model; it omits activity coefficients, temperature effects and weak-acid equilibria.

## Controls

- Q: add 0.5 mL
- W: add 1.0 mL
- E: add 2.5 mL
- Enter: lock the endpoint
- R: restart the current incomplete sample
- N: advance after a successful sample
- On-screen buttons support mouse and touch.

Each sample awards 100 points once. A completed sample cannot be reset to farm points; a completed campaign can be restarted as a new run.

## Import

- Standalone: open this folder in Godot 4.3+ and run main.tscn.
- Repository Test Hub: open the repository root and launch KROLL Titration Bench; the hub loads main_root.tscn.
- No external assets, plugins, audio, network or runtime services are required.

## Validation

- tests/rules_test.gd covers pH calculation, equivalence volumes, allowed addition sizes, early submissions, score integrity and campaign transitions.
- tests/game_smoke_test.gd exercises the playable scene, all three samples, scoring and campaign restart.
- Local GUI/GPU/device QA is separate from cloud headless validation.
