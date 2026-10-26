# 3D Prototype Feedback Fix M0.1 — 2026-10-26

## User-observed issues
- Player visual looked like a capsule placeholder.
- World contained only perimeter walls and sparse dividers, not winding exploration corridors.
- Runtime window appeared too small when maximized.
- Right mouse drag did not rotate the view.

## Fix scope in this PR
- Add right-mouse-held camera look with Escape to release mouse.
- Make movement relative to player yaw and tune camera FOV/third-person position.
- Start the game window maximized and improve HUD legibility.
- Replace the capsule-only placeholder with a simple procedural humanoid silhouette.
- Replace sparse interior dividers with deterministic winding corridor segments in the Backrooms room.

## Important limits
This is still a playable prototype, not the complete game. Corridor generation is bounded to the current room; infinite chunk streaming and polished character assets are not implemented by this change. CI validation and graphical playtesting are required before merge.
