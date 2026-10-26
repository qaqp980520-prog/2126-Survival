# KROLL Hydroponics Shift M0.1

A standalone Godot 4 crop-care arcade game. Maintain three hydroponic beds and harvest ten crops before the 90-second shift ends.

## Controls
- 1, 2, 3: water beds 1–3.
- Q, W, E: harvest beds 1–3 when ready.
- Touch/click the upper part of a bed card to water; touch/click the lower part to harvest.
- R: restart after the round ends.

## Rules
- Each bed starts at 65% moisture.
- Water adds 28 moisture points, capped at 100.
- Crops grow at 18 percentage points per second while moisture is at least 12.
- Moisture drains at 7 points per second until the crop is ready.
- Harvesting a ready crop grants 15 credits and replants at 45% moisture.
- Reach 10 harvests before 90 seconds expire to win.

## Requirements
- Godot 4.3 or later.
- No external assets or add-ons.
- Open this folder's project.godot in Godot Project Manager.

## Validation
The repository CI imports the project, runs rule boundary tests, and runs a headless main-scene smoke test. Manual visual play and iPhone touch testing have not yet been performed.
