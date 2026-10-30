# KROLL Orbital Imager M0.1

A camera-framing and observation puzzle for Godot 4.3+.

## Objective

Capture all three green survey targets inside one camera frame while keeping every red interference source outside the frame. Each assignment allows three shutter attempts. Camera pan and zoom are the only aiming controls.

## Controls

- WASD / arrow keys: pan the camera frame
- Q / E: zoom out / zoom in
- Space: take a photograph
- R: restart the current assignment
- N: move to the next assignment
- On-screen buttons support mouse and touch.

## Assignments

- Lunar Beacon Array
- Crater Relay
- Orbital Debris Field

## Import and validation

Open project.godot with Godot Project Manager. No external assets, add-ons, audio or network access are required. Deterministic rules and scene smoke tests are in tests/.

## Limits

M0.1 uses three authored 2D survey maps and a deterministic rectangular field of view. It has no saved campaign progress, procedural maps or 3D orbital camera.
