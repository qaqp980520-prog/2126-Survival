# KROLL Mess Hall Rush M0.1

A turn-based station-cafeteria time-management game for Godot 4.3.

## Gameplay

- Complete three shifts: Dockside Breakfast, Midday Rush and Night Shift.
- Each shift contains four authored orders and recipe-specific workstation sequences.
- Select an order, then choose the next required station action.
- Every action advances the countdown of all unfinished orders; incorrect actions and WAIT consume time.
- Serve at least three of four orders to pass a shift. Complete all three shifts with at least nine served orders to win the campaign.
- Score is awarded once when an order is completed. The immutable rules API prevents UI retries from mutating an earlier state.

## Controls

- 1–4: select an order.
- Q W E R T Y U I O P: CHOP, GRILL, SIMMER, BREW, CHILL, BUTTER, GLAZE, WASH, PLATE, POUR.
- Space: WAIT.
- Enter: perform the selected order's expected station action.
- Buttons support mouse and touch.

## Import

Open project.godot in Godot 4.3 and run main.tscn.

The root Survival Test Hub launches main_root.tscn. No addons, external assets, network access or world-save migration are required.

## Model limits

This is a deterministic queue-and-deadline puzzle, not a real food-safety, cooking-temperature or nutrition simulator.
