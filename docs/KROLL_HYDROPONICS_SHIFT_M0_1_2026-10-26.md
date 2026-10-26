# KROLL Hydroponics Shift M0.1 — 2026-10-26

## Files
- daily_games/KROLL_Hydroponics_Shift/project.godot
- daily_games/KROLL_Hydroponics_Shift/main.tscn
- daily_games/KROLL_Hydroponics_Shift/main.gd
- daily_games/KROLL_Hydroponics_Shift/rules.gd
- daily_games/KROLL_Hydroponics_Shift/tests/rules_test.gd
- daily_games/KROLL_Hydroponics_Shift/tests/game_smoke_test.gd
- daily_games/KROLL_Hydroponics_Shift/README.md

## Gameplay
A 90-second crop-care arcade shift with three grow beds. Water with 1/2/3, harvest mature beds with Q/W/E, and reach ten harvests. Touch/click the upper half of a bed to water and the lower half to harvest. No external assets or add-ons.

## Dependencies and import
Godot 4.3 or later. Open daily_games/KROLL_Hydroponics_Shift/project.godot in Godot Project Manager.

## Validation
- Automated Godot 4.3 headless project import, rule tests, and scene smoke test are wired into the shared CI workflow.
- Status before CI: pending; do not call it tested until the workflow completes successfully.
- Manual GUI and iPhone touch testing have not been performed.

## Limitations / next steps
No save system, crop variety, sound, or difficulty progression yet. After automated validation, consider adding an optional pause control and verify visual layout at mobile aspect ratios.
