# KROLL Reactor Deck Command M0.1

A deterministic, turn-based card combat game. Protect the reactor core through three encounters by spending three energy each turn on attacks, block, repairs and card draw.

## Encounters
1. Coolant Leak — 26 HP, 5 attack, no escalation.
2. Surge Drone — 34 HP, 7 attack, +1 attack each turn.
3. Core Sentinel — 42 HP, 8 attack, +1 attack each turn.

The core starts with 36 HP. HP, draw pile and discard pile carry between encounters. Each encounter awards 100 points once; the campaign maximum is 300.

## Cards
- Arc Bolt: 1 energy, 6 damage.
- Brace: 1 energy, 7 block.
- Pulse: 1 energy, 4 damage and 4 block.
- Repair: 2 energy, restore up to 5 core HP.
- Overload: 2 energy, 12 damage and 2 recoil.
- Coolant: 0 energy, 3 block and draw one card.

The 15-card starter deck is shuffled from a fixed seed. Empty draw piles reshuffle the discard pile deterministically.

## Controls
- 1–5: play the corresponding card in hand.
- E: end turn and resolve the enemy's telegraphed attack.
- N: advance after defeating an encounter.
- R: restart the campaign.
- Mouse/touch: tap card buttons and action controls.

## Run
Open the project.godot file in Godot 4.3+ and run main.tscn. The root Survival Test Hub loads main_root.tscn.

## Files and dependencies
- project.godot, main.tscn, main_root.tscn
- main.gd, rules.gd
- tests/rules_test.gd, tests/game_smoke_test.gd
- Godot 4.3+ only. No external assets, add-ons, network calls or world-save dependency.

## Validation and limits
The game has deterministic rules, a three-encounter campaign, five visible card buttons, mouse/touch controls and keyboard shortcuts. It is not a full deck-building game: the starter deck is fixed, enemies use telegraphed direct attacks, and there are no persistent upgrades or saved campaign records. Cloud Godot 4.3 CI is the engine validation target; local rendered GUI/GPU and physical iPhone testing must be recorded separately.
