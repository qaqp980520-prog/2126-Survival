# KROLL Archive Curator M0.1

A card-and-layout curation puzzle. Build a four-item exhibit from six artifacts, match the gallery theme, and place shared-tag items orthogonally adjacent to earn synergy points.

## Galleries

1. Engineering Wing
2. Life Sciences Wing
3. Exploration Wing

Each gallery has six authored artifacts and four exhibit cases. The player chooses four distinct items. Score is:

- Sum of artifact base values.
- +3 for each item containing the gallery theme tag.
- +2 for each orthogonally adjacent pair sharing at least one tag.

A gallery passes only when all four cases are filled, at least two items match the theme, and the target score is reached. Diagonal cases do not create a synergy link. Each gallery awards its score once; a passed gallery cannot be replayed for duplicate points.

## Controls

- 1–6: select an archive item.
- Q / W / A / S: place the selected item in cases A / B / C / D.
- Backspace / Delete: recall the most recently placed item.
- R: reset the current unpassed gallery.
- N: advance after a gallery passes.
- C: restart the full campaign.
- Mouse/touch: select item buttons, then tap an exhibit case; use the four action buttons below the board.

## Files

- project.godot: standalone Godot project.
- main.tscn, main_root.tscn: standalone and root Test Hub scenes.
- main.gd: runtime UI, input and campaign state.
- rules.gd: deterministic placement validation and exhibit scoring.
- tests/rules_test.gd: score, adjacency, duplicate and bounds tests.
- tests/game_smoke_test.gd: scene, campaign progression, score-once and recall checks.

## Import

Open daily_games/KROLL_Archive_Curator/project.godot in Godot Project Manager, or launch it from the root Survival Test Hub.

## Dependencies and limitations

- Godot 4.3+.
- No external assets, add-ons, audio files, network calls or world-save dependencies.
- The scoring model is an authored puzzle abstraction, not a real museum-planning or collection-management system.
- Cloud headless validation does not replace local rendered playtesting, GPU checks or physical iPhone touch QA.
