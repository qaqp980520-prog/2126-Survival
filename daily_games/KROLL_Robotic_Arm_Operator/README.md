# KROLL Robotic Arm Operator M0.1

A precision pick-and-place operator game built with Godot 4.3 or newer.

## Objective
Complete three KROLL work orders by aligning a two-link robotic arm with each payload, closing the gripper, moving the payload to the marked receiving dock and releasing it inside the delivery radius.

## Controls
- A / D: rotate the shoulder joint.
- W / S: rotate the elbow joint.
- Space: close the gripper to pick up a payload, or open it to deliver.
- R: restart the three-work-order campaign.
- On-screen shoulder/elbow step buttons, gripper and reset buttons support mouse and touch.

Releasing a payload outside the receiving dock drops it and fails the current campaign attempt; reset to retry.

## Simulation
- Two-link forward kinematics with explicit shoulder and elbow joint limits.
- Inverse-kinematic work-order positions are validated by deterministic rules tests.
- Three distinct payload/dock pairs, pickup and delivery radii, joint adjustment counter and campaign completion state.
- No external art, audio, plugins or network dependencies.

## Import and test
Open this folder's project.godot in Godot 4.3 or newer. The root and nested main.gd/rules.gd mirrors are kept byte-identical so the scene works from both the standalone project and repository root.

Run the Godot editor import, then tests/rules_test.gd and tests/game_smoke_test.gd in headless mode.
