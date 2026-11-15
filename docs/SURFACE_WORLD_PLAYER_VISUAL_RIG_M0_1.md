# Production SurfaceWorld Player Visual Rig M0.1.5 — Touch HUD Layout Regression

## Purpose

Replace the single capsule visual placeholder with a lightweight procedural low-poly KROLL field-suit character rig. Keep the player physics and camera contract unchanged.

## Implementation

- `world/SurfaceWorld.gd` builds a `PlayerVisualRoot` under the existing `CharacterBody3D`.
- The visual rig contains a torso/chest plate, helmet/visor, backpack, separately pivoted arms and legs, knee guards, boots and small safety accents.
- Reusable primitive mesh helpers create capsules, spheres and boxes with shared `StandardMaterial3D` materials.
- Procedural locomotion resolves five states from existing physics values: idle, walk, sprint, jump and fall.
- Walk/sprint use opposing arm/leg swing, body bob and a forward sprint lean; jump/fall use distinct arm and leg poses with smoothed transitions.
- Animation reads the existing `CharacterBody3D.velocity`, `is_on_floor()` and `_sprint_active`; it does not alter movement, stamina, carry penalties or streaming.

## Compatibility contract

- Player root remains `CharacterBody3D`.
- `CollisionShape3D` remains `CapsuleShape3D`, radius 0.35 and height 1.8.
- First-person `Camera3D` remains at local position `(0, 1.48, 0)` with its existing FOV. Desktop look remains right-mouse capture plus mouse motion. Touchscreen look tracks only screen-touch indices whose initial press reaches `_unhandled_input`; Interactive HUD Controls own their hit regions, while display-only `WorldStatus` and `InteractionPrompt` labels use `MOUSE_FILTER_IGNORE` and remain transparent to camera-look gestures. Only the first eligible world touch drives look, additional eligible world touches queue for handoff, and releasing the active touch stops its drag deltas. Both desktop and touch paths share the same yaw/pitch sensitivity and pitch clamp. Helmet, visor and beacon geometry use dedicated visual layer 20, excluded from the first-person camera to prevent head/visor occlusion; external cameras can include that layer.
- No world-save schema, chunk ID, inventory, stamina, underground, input or interaction behavior changes.
- Non-headless runtime creates the actual MeshInstance3D meshes. The headless regression invokes the same builder but uses metadata-only Node3D descriptors, avoiding dummy-renderer mesh creation while verifying the hierarchy and primitive geometry types.

## Files

- `world/SurfaceWorld.gd`
- `tests/production_surface_world_player_visual_test.gd`
- `tests/production_surface_world_touch_look_test.gd`
- `tests/production_surface_world_touch_layout_test.gd`
- `.github/workflows/godot-validation.yml`
- `.github/workflows/surface-world-player-visual-validation.yml`
- `docs/SURFACE_WORLD_PLAYER_VISUAL_RIG_M0_1.md`

## Dependencies and import

- Root Godot 4.3 project and existing `world/SurfaceWorld.tscn`.
- No external model, texture, plugin, import step or third-party asset is required; all meshes/materials are generated at runtime.
- Import and test from repository root:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_player_visual_test.gd
godot --headless --path . --script res://tests/production_surface_world_touch_look_test.gd
godot --headless --path . --script res://tests/production_surface_world_touch_layout_test.gd
```

## Validation and limitations

- The focused player-visual regression checks player root/collision/camera invariants, confirms the first-person camera excludes helmet layer 20, verifies head-geometry layer assignments, rig node structure, all five state-resolution cases and representative pose transitions.
- The touch-look regression sends a raw screen-touch event through the production `_unhandled_input` handler at the HUD jump button's viewport-space center, verifies the recursive HUD Control hit test excludes that finger from camera-look ownership, and sends its drag through the same handler to confirm yaw/pitch remain unchanged. An open-world touch is verified as eligible for look; deterministic cases cover pitch clamps, queued-finger handoff, release cleanup and desktop mouse-look compatibility. Standard Control activation from a physical touch/mouse-emulation event is not claimed by headless CI and remains a device-level check.
- Full Godot 4.3 compatibility CI also runs the existing SurfaceWorld integration, carry movement, stamina, streaming, save/restore and interaction suites.
- Headless CI verifies the HUD hit-test ownership guard and deterministic pose logic. It does not verify standard Control activation through the operating-system touch-to-mouse emulation path, physical touchscreen latency, gesture ergonomics, rendered materials, silhouette, shadows, camera clipping or mobile GPU appearance. A non-headless touch-device run remains required before treating the character art and mobile controls as final.
- This is an in-engine procedural placeholder rig, not a final authored/rigged character asset. It can later be replaced by an imported model while preserving the pivot/state interface.

## Run 132 — touch gesture ownership hardening

- Prevent camera-look leakage from HUD interactions by tracking only touch indices whose initial press reaches the unhandled world-input path. GUI-owned button presses are not registered as look fingers.
- The first eligible world touch controls look; other eligible world touches wait and take over when the active touch is released. Drag events from released or untracked fingers are ignored.
- Updated runtime source: `world/SurfaceWorld.gd`; regression: `tests/production_surface_world_touch_look_test.gd`; this document records the compatibility contract and test coverage.
- No external assets or plugins. Godot 4.3 root project is required. Import and run the touch regression with `godot --headless --path . --editor --quit` then `godot --headless --path . --script res://tests/production_surface_world_touch_look_test.gd`.
- The initial synthetic ownership-state test passed in focused CI. A real GUI Control pipeline regression was added in Run 133; its exact-head CI is pending.

## Run 133 — superseded real HUD touch-routing experiment

- This was an intermediate attempt, not the final accepted test scope. The later headless GUI activation scope correction below supersedes its Button-activation assertions.
- Extended `tests/production_surface_world_touch_look_test.gd` to use `Viewport.push_input` against the production HUD jump button.
- The test checks that the jump button receives the touch and sets `_touch_jump`, the touch index is not added to `_touch_look_indices`, dragging the same finger does not alter player yaw or camera pitch, and releasing the touch clears the jump state.
- Existing synthetic cases remain for world-touch yaw/pitch, upper/lower clamps, queued-finger handoff, release cleanup and desktop mouse-look compatibility.
- Runtime code is unchanged in this test-only follow-up. The updated exact-head focused and full Godot 4.3 CI results must pass before this expanded GUI-routing coverage is considered validated.
- Physical iPhone latency, touch ergonomics and non-headless rendering remain outside headless CI.

## Run 133 — HUD hit-test correction after exact-head failure

- The first real-viewport attempt failed because a raw `InputEventScreenTouch` sent through `Viewport.push_input` did not activate the standard HUD Button in the headless test; the same touch was then treated as unhandled and rotated the camera. This is an important distinction between raw screen-touch delivery and the mouse-emulation path used by standard Controls.
- Runtime correction: `_is_touch_over_hud_control(screen_position)` recursively checks visible, non-ignored Controls beneath the `HUD` CanvasLayer. A screen touch beginning inside a HUD Control is excluded from `_touch_look_indices`, independent of whether the raw touch event itself is consumed by GUI.
- An intermediate follow-up attempted `Input.emulate_mouse_from_touch` and `Input.parse_input_event` to exercise standard Control activation. The headless SceneTree did not reliably reproduce that GUI path; this attempt was superseded and no Button-activation pass is claimed.
- Previous candidate `83a42a1b180ab0e51854276f1f0db5fd3fbd3696` failed the focused GUI-routing test; its 18/20 matrix at failure time is not a passing candidate. The corrected exact-head CI must run before this change is accepted.


## Run 133 — HUD canvas coordinate correction (intermediate test iteration)

- The first recursive hit-test used `Control.get_global_rect()` directly against the screen-touch position. CI showed that the button rectangle was laid out but the event coordinate did not match the untransformed rect.
- The hit test now converts the viewport touch position into each Control's local space using `get_global_transform_with_canvas().affine_inverse()` and checks `Rect2(Vector2.ZERO, control.size)`. This accounts for CanvasLayer/viewport transforms instead of assuming the control's global rect and input position share an untransformed coordinate space.
- The final regression explicitly asserts that the jump button center maps inside the HUD hit test. The later headless GUI activation scope correction below removes the unsupported emulated Button-activation assertion.


## Run 133 — intermediate raw-touch and Control-emulation split

- The `Input.parse_input_event` attempt did not reproduce the expected Control event routing in the headless SceneTree. The test was revised to keep the two engine paths explicit instead of claiming a complete OS touch simulation.
- Raw `InputEventScreenTouch` and `InputEventScreenDrag` are sent directly through the production `_unhandled_input` handler at the HUD button's viewport-space center. The HUD hit-test must exclude the touch and prevent yaw/pitch changes.
- An intermediate experiment also pushed the emulated mouse press/release through the viewport, but this did not reliably activate the production Button in the headless SceneTree. That assertion was removed by the final scope correction below; no Control-activation pass is claimed.
- This intermediate attempt is historical. Current headless evidence is limited to raw-touch ownership and deterministic camera-look state, not the complete GUI/OS touch-emulation path.


## Run 133 — headless GUI activation scope correction

- The headless attempt to push an emulated `InputEventMouseButton` into the viewport did not activate the production HUD Button. This is a GUI/input-emulation limitation of the synthetic headless path, not evidence that the production button is broken.
- Removed that unsupported activation assertion rather than claiming a pass. The deterministic regression now focuses on the production raw-touch handler: a touch beginning over the jump Control is excluded from camera-look ownership, its drag cannot alter yaw/pitch, and a touch in open world space remains eligible.
- Physical HUD Button activation, touch-to-mouse emulation, gesture latency and iPhone behavior remain explicitly unverified until a non-headless device run.


## Run 136 — display-only HUD input pass-through

- Review found that the recursive HUD hit test correctly treats non-ignored Controls as input-owned, but the two display-only `Label` nodes (`WorldStatus` and `InteractionPrompt`) retained the default STOP mouse filter. Their full control rectangles could therefore suppress camera look even though they have no action.
- Set both labels to `Control.MOUSE_FILTER_IGNORE`; interactive touch buttons and the diagnostics panel retain their existing input ownership.
- Extended `tests/production_surface_world_touch_look_test.gd` to verify each label is ignored by GUI hit testing, its viewport-transformed center is not claimed by the HUD guard, and a touch/drag over that label can register and rotate the camera. Existing jump-button exclusion, open-world touch, pitch clamps, queued-finger handoff, release cleanup and desktop mouse-look checks remain.
- Files: `world/SurfaceWorld.gd`, `tests/production_surface_world_touch_look_test.gd`, this document.
- Dependencies/import: root Godot 4.3 project and `world/SurfaceWorld.tscn`; no external assets or import step. Run editor import then the touch-look script from repository root.
- Validation: pending exact-head focused and full Godot 4.3 CI. No new-head pass is claimed until both complete.
- Limitations: headless tests validate deterministic input ownership and yaw changes, not physical iPhone touch latency, OS touch-to-mouse Control activation or rendered GPU behavior.


## Run 137 — production touch-control layout regression

- Added `tests/production_surface_world_touch_layout_test.gd` to verify the fifteen production HUD touch buttons are present, visible, non-zero, non-overlapping, fully inside the TouchControls PanelContainer and inside the active viewport.
- The regression also verifies the InteractionPrompt remains inside the viewport and does not overlap the touch-control panel or any touch button. This protects the compact bottom-center control cluster from accidental clipping or prompt overlap as the HUD changes.
- Added the test to both `.github/workflows/surface-world-player-visual-validation.yml` and the full `.github/workflows/godot-validation.yml` gate. The focused workflow path filters include the new test file.
- Runtime gameplay code is unchanged in this run; the work adds deterministic layout assertions and CI coverage only.
- Run from the repository root with `godot --headless --path . --editor --quit` followed by `godot --headless --path . --script res://tests/production_surface_world_touch_layout_test.gd`.
- Validation status at authoring: pending exact-head Godot 4.3 focused and full CI. Headless layout geometry does not validate OS touch-to-mouse activation, physical device safe-area behavior, rendered GUI appearance or iPhone latency.


## Run 140 — window-focus interruption regression

- Extended `tests/production_surface_world_touch_look_test.gd` to cover all three production interruption notifications: `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_APPLICATION_PAUSED`, and `NOTIFICATION_WM_WINDOW_FOCUS_OUT`.
- Each path now asserts that held movement directions, jump, sprint, active world-look fingers, the jump-edge latch, active sprint state and mouse-look capture are cleared, and that the mouse cursor is released.
- The window-focus case additionally sends a stale drag for the previously active finger and verifies that neither player yaw nor camera pitch changes.
- Runtime implementation is unchanged; this is a regression-coverage expansion for the existing `_clear_touch_input_state()` contract.
- Exact-head focused and full Godot 4.3 CI for the resulting commit are pending; do not treat this version as validated until those checks complete.
- Physical iPhone suspension/resume behavior and non-headless GUI/GPU rendering remain device-QA items.
