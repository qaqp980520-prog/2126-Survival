# KROLL Span Engineer M0.1

A deterministic bridge-design puzzle for Godot 4.3+.

## Objective

Build five spans that can carry a cart load of 3 without exceeding the material budget of 12. Standard decks cost 1 and carry 2; reinforced decks cost 3 and carry 3; an anchored brace costs 1 and adds 1 capacity. Each blueprint places three anchors on different spans, so the player must combine standard decks with braces and reinforced decks on unsupported spans.

## Controls

- Click/tap a deck card to cycle Empty -> Standard -> Reinforced -> Empty.
- Click/tap an anchor brace card to toggle support.
- T runs the load test; failed tests allow redesign.
- R resets the current blueprint; N advances to the next deterministic blueprint.
- Keyboard, mouse and touch are supported.

## Import

Open project.godot in Godot 4.3 or newer. No external assets or addons are required.

## Tests

- tests/rules_test.gd: deterministic blueprints, budget enforcement, anchor constraints, capacity calculation, repair after failed tests, all three solutions and terminal edit lock.
- tests/game_smoke_test.gd: scene construction, UI controls, live edit actions, load-test win and blueprint switching.
