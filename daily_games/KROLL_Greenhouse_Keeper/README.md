# KROLL Greenhouse Keeper M0.1

A deterministic resource-management mini-game built with Godot 4.3+ and no external assets or add-ons.

## Import

Open this folder's project.godot in Godot Project Manager.

## Goal

Harvest at least five produce units by the end of day seven. Tomatoes yield three units; wheat and carrots yield two each. Each plot begins at 50% moisture, daily cycles consume 25 moisture and grow a crop by one stage when the soil has enough moisture. The water tank starts with three charges; each watering adds 25 moisture. A crop is harvestable at stage 3.

## Controls

- Click/tap a plot or press 1, 2 or 3 to select it.
- W or the WATER PLOT button waters the selected plot.
- D or ADVANCE DAY advances the greenhouse by one day.
- H or HARVEST harvests a mature selected crop.
- R restarts the current deterministic layout.
- N advances to the next layout.

The game uses a fixed seed for each layout, so the same seed always produces the same crop order. Rules and runtime smoke tests are included under tests/.
