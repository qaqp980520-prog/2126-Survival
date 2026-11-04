# Run 120 — KROLL Fossil Extraction Lab M0.1

## Asset

- Repository path: daily_games/KROLL_Fossil_Extraction_Lab/
- Entry point: project.godot → main.tscn → main.gd.
- Rules: rules.gd.
- Tests: tests/rules_test.gd and tests/game_smoke_test.gd.
- Dependency: Godot 4.3+ with Compatibility renderer; no external assets or plugins.
- Import: open project.godot in Godot 4.3+, allow the editor import, then run main.tscn.

## Gameplay

Three 8×8 excavation sites labeled A1–H8: Triceratops Horn, Ammonite Coil and Raptor Claw. Each site provides a coordinate survey clue so scanner placement is a deliberate decision rather than blind guessing. The scanner reports fossil count in a selected 3×3 sector; Air Scribe clears one sediment layer over a 3×3 sector; Brush safely clears one cell; Micro Chisel clears two layers but damages a fossil on contact. Each site has a 16-action budget and specimen-integrity meter. Rewards are one-time per site.

## Verification

- Rules tests cover all three authored specimens and the perfect scan → air → brush route.
- Runtime smoke test checks the 64-cell interface and campaign progression.
- Godot engine validation must be recorded from the exact candidate SHA. Until CI completes, status is pending.

## Limitations

- Grid-based excavation simulation; no 3D soil deformation or particle effects.
- Specimen silhouettes are abstract cell clusters rather than anatomical meshes.
- Local GUI/GPU and physical iPhone QA are not claimed by headless CI.
