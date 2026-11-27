# Life Journey — project status

Last updated: 2026-11-27

## Product direction
The user has explicitly changed the visual direction: Life Journey must be **2D, not 3D**. It should use real approved photographs as character portraits/cut-outs where possible, with a playable scene-based life simulation rather than a slideshow.

Main character: the person identified by the user as the man standing in the middle of the three-person night photograph, wearing a black T-shirt. This selection is user-confirmed.

## Repository
- Repository: ntambalikachimwemwe-prog/Who-am-l-whatsapp
- Development branch: life-simulator-game
- Project root: life-simulator/
- Main scene: res://scenes/main.tscn

## 2D implementation added
- 2D Node2D main scene and script.
- Four life stages: primary school, secondary school, university and adult life.
- Illustrated 2D backdrops for each stage.
- Keyboard movement, camera follow, stage switching, nearby NPC interaction and typed dialogue.
- Optional portrait loading from res://assets/characters/ so approved real photographs can replace fallback character drawings.

## Important remaining work
- The uploaded photos have not yet been packaged into the repository as optimized portrait assets. The current game therefore uses simple 2D fallback figures until portrait files are added.
- Stage locations are illustrated 2D scenes, not photorealistic 360-degree environments.
- NPC dialogue is scripted, not a live AI conversation.
- No verified APK, web deployment, or tested release artifact is recorded yet.
- A successful Godot 4.4.1 import/export and real-device/browser test is required before calling this a release.

## Consent and privacy
Use identifiable photos of friends only when each person has agreed to their likeness being used in the game. Avoid using WhatsApp screenshots/status captures; use original photos cropped to remove app UI and private information.
