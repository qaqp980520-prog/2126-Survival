# KROLL Paleo Track Lab M0.1

A deterministic dinosaur trackway interpretation game for Godot 4.3+.

## Objective

Inspect three fossil trackways and submit a field report identifying the trackmaker, gait and heading. The game displays measured footprint length/width, stride length, trackway gauge and toe bearing. Correct conclusions are derived from those measurements by the rules module rather than stored as visible answer labels.

Sites: Fern Basin, Ridge Pass and River Plain.
Trackmaker categories: Small Ornithopod, Large Theropod and Sauropod.

Each correct report awards 100 points. A wrong report fails the current site; reset it to retry without losing score earned at earlier sites.

## Controls

- 1 / 2 / 3: select Small Ornithopod / Large Theropod / Sauropod
- 4 / 5: select Walk / Run
- Arrow keys: select N / E / S / W
- Page Up / Page Down / Home / End: select NE / SE / NW / SW
- Enter: submit the field report
- R: reset an unfinished or failed site
- N: advance after a correct report
- Mouse/touch: use the on-screen answer and action buttons

## Files

- `project.godot`, `main.tscn`: standalone Godot project.
- `main_root.tscn`: root-project Test Hub scene entry.
- `main.gd`: procedural trackway sketch, measurement panel, keyboard and touch controls.
- `rules.gd`: deterministic measurement classification, answer validation and campaign scoring.
- `tests/rules_test.gd`: three site classifications, heading quantization, invalid answers, wrong-report failure, reset and campaign completion.
- `tests/game_smoke_test.gd`: scene instantiation, UI controls, wrong report, retry and successful progression.

No external assets, audio, plugins, network access or save system. The track sketches are drawn procedurally from the authored measurements. This is a simplified educational game model, not a scientific fossil-identification tool.
