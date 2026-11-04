# KROLL Abyssal Sonar M0.1

- Project path: daily_games/KROLL_Abyssal_Sonar/
- Engine: Godot 4.3+, Compatibility renderer.
- Gameplay: three 9×9 turn-based deep-trench searches; the beacon is hidden from the map. Sonar pings reveal an eight-way bearing and coarse Manhattan-distance band. Move through visible rock walls, collect the beacon and return to the SUB tile.
- Costs: 1 battery per move, 2 per sonar ping, three pings per mission. Each mission has a finite battery budget.
- Scoring: 100 points when extracted at or above the mission's par battery reserve, otherwise 75; each mission can award once, campaign cap 300.
- Controls: WASD/arrows move; Space ping; E collect/extract; R restart; N next; C new campaign. On-screen controls support pointer/touch.
- Tests: rules_test.gd validates reachability, sonar clues, battery/ping budgets, extraction, score and award ledger; game_smoke_test.gd validates scene/actions/touch hit testing; route_simulation_test.gd executes all three missions through real movement and return.
- Dependencies: no external assets, plugins, audio, network or save dependencies.
- Limitations: deterministic grid puzzle, not fluid simulation; local GUI/GPU/iPhone QA requires a real Godot GUI/device.
