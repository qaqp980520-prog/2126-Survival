# KROLL Beat Lab M0.1

A self-contained rhythm timing game for Godot 4.3+. No external assets, plugins, or audio files are required. The chart patterns are original deterministic data and the playfield provides a visual metronome.

## Import

Open this folder's project.godot from Godot Project Manager, then run main.tscn.

## Controls

- A / S / D / F: hit the matching lane.
- R: restart the current chart.
- N: advance to the next chart.
- On-screen lane buttons support mouse and touch input.

## Rules

- 100 BPM; 24 notes per chart across four lanes.
- Hit window: +/- 0.18 seconds around the note time.
- Each clean hit awards 100 points.
- A chart clears at 1,800 points or more with no more than four misses.
- Three fixed original charts are included.
- The game contains no third-party or copyrighted music.

## Validation

Run tests/rules_test.gd for deterministic rule tests and tests/game_smoke_test.gd for scene/button-signal smoke coverage. The repository's Godot 4.3 GitHub Actions workflow is the canonical engine validation; local device/GPU testing is separate.
