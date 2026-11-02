# KROLL Crew Ledger M0.1

A Godot 4 logic-grid assignment game. Each case has four crew members, four stations and four constraints. Assign each crew member to one unique station, then verify the manifest.

## Controls

- Click/tap a crew row to cycle its station assignment.
- Keyboard 1–4 selects and cycles a row.
- Space cycles the selected row.
- Enter verifies the manifest.
- R resets the current case while preserving earlier score.
- N advances after a correct case.

## Cases

1. Relay Blackout
2. Cryo Alert
3. Observatory Shift

Each authored case has exactly one valid assignment. The rules test enumerates all 24 one-to-one permutations per case and verifies uniqueness.

## Import and run

Open this folder as a Godot 4.3+ project, or open the root project and launch KROLL Crew Ledger from the Survival Test Hub.

No external assets, plugins, audio, network access or third-party dependencies are required.

## Tests

- rules_test.gd: clue uniqueness, invalid input, duplicate station, scoring, reset and campaign progression.
- game_smoke_test.gd: UI construction, clue visibility, assignment input, submission and case progression.
- Root CI instantiates the game through the Survival Test Hub.
