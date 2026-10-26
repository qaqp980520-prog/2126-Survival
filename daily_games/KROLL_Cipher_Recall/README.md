# KROLL Cipher Recall M0.1

A standalone Godot 4.3+ memory-sequence arcade game. Watch the 3x3 tiles light up, then repeat the sequence. Five rounds increase the sequence length from three to seven cells. Three cores are available; a wrong input costs one core and replays the current sequence.

## Controls

- Keys 1–9: select the matching tile.
- Mouse click or screen touch: select a tile.
- R: restart after a win or failure.

The game uses procedural drawing and has no external assets or third-party addons.

## Import

Open this folder's project.godot in Godot Project Manager.

## Automated tests

- Import/parse: godot --headless --path daily_games/KROLL_Cipher_Recall --editor --quit
- Rules: godot --headless --path daily_games/KROLL_Cipher_Recall --script res://tests/rules_test.gd
- Runtime smoke: godot --headless --path daily_games/KROLL_Cipher_Recall --script res://tests/game_smoke_test.gd

Automated headless validation does not replace graphical manual play or iPhone device testing.
