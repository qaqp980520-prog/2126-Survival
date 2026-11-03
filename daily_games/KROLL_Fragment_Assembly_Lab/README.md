# KROLL Fragment Assembly Lab M0.1

A Godot 4.3 string-overlap puzzle. Reconstruct three fictional sample strings by choosing fragments whose prefixes overlap the assembled suffix by at least two characters.

## Gameplay

- Start from the seed fragment shown in each lab.
- Select the only fragment that creates a valid prefix of the hidden target.
- A wrong fragment consumes one mismatch allowance; three mismatches fail the lab.
- Complete all three labs to finish the campaign.
- Each lab awards score once; completed labs cannot be replayed for duplicate points.
- The fragment order is deterministic and each step has exactly one valid next fragment.

## Controls

- 1–5: choose a visible fragment.
- R: restart the current lab (only before it is passed).
- N: advance after passing a lab.
- Mouse and touch: use the on-screen fragment and control buttons.

## Import

Open project.godot in Godot 4.3 and run main.tscn. The root Survival Test Hub opens the same scene.

No external assets, add-ons, network access or world-save migration are required.

## Scope and safety

The A/C/G/T strings are fictional puzzle tokens used only for string-matching logic. This project does not model real genes, organisms, laboratory protocols or biological experimentation.
