# KROLL Cargo Audit M0.1

A deterministic manifest-investigation puzzle for Godot 4.3+.

## Objective

Inspect four inbound containers across three cases. Each case has exactly one discrepancy in mass, seal identity or item count. A briefing identifies one certified field, leaving two fields to investigate. Use at most eight scans and two accusations to identify the incorrect container and field.

## Controls

- 1–4: select container A–D
- M / S / C: select mass / seal / count
- Space: scan the selected container and field
- Enter: submit the selected container and field as the suspect
- R: reset the current case
- N: next case after the current case ends
- On-screen buttons support mouse and touch.

## Cases

- Dock 17 — mass/count investigation; seal is certified.
- Cold Chain — seal/count investigation; mass is certified.
- Deep Storage — mass/seal investigation; item count is certified.

## Import and validation

Open project.godot with Godot Project Manager. Godot 4.3 or newer is required. No external assets, audio, plugins or network access are required. Deterministic rules tests and a scene smoke test are in tests/.

## Limits

M0.1 uses three authored cases and fixed manifests. It has no generated cargo manifests, persistent campaign scores, multiplayer or external inventory integration.
