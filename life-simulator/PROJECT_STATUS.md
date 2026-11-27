# Life Journey — project handoff and release status

Last updated: 2026-11-27

## Repository and safety
- Repository: `ntambalikachimwemwe-prog/Who-am-l-whatsapp`
- Active development branch: `life-simulator-game`
- Keep the repository's default/main branch unchanged. The original app belongs there.
- Godot project root: `life-simulator/`
- Main scene: `res://scenes/main.tscn`
- Engine target: Godot 4.4.1 in GitHub Actions.

## Product brief
Life Journey is intended to be a third-person, open-world life simulation. The player controls one visible character and can explore environments, approach people, and type dialogue for the character. It should ultimately target Windows and Android.

The four planned life stages are:
1. Primary school — classroom teaching, classmates, school grounds, returning home and family.
2. Secondary school — hostel and dormitory life, friends, music and football conversations.
3. University — lecture rooms, campus, library, friendships and respectful dating/relationship interactions.
4. Adult life — home, work, shops, neighbourhood and relationships.

The game should feel like a continuous explorable world, with human characters and believable environments, rather than a quiz or a slideshow.

## Current implementation
- Godot 4 project with a third-person CharacterBody3D player.
- Keyboard/mouse controls and touchscreen movement, run, jump, talk and stage-change controls.
- Four procedural stage environments with buildings, furniture, trees and named NPCs.
- Typed dialogue panel with simple keyword-based NPC replies.
- Player and NPCs now use separate head/torso/arm/leg meshes rather than a single capsule silhouette; the player limbs swing during movement.
- GitHub Actions workflow at `.github/workflows/life-journey.yml` installs Godot 4.4.1 and the matching official export templates, validates/imports the project, runs a headless scene smoke test, then attempts Web and Windows exports.

## Honest release status
This is still an early playable foundation/blockout, not a finished commercial-quality GTA-style game. The characters are procedural low-detail models, not photorealistic or rigged character assets. The environments are geometric blockouts, not finished detailed locations. NPCs do not yet navigate autonomously. Dialogue is scripted, not AI-driven. There is no complete mission/career progression, robust relationship system, save/load, vehicles, traffic, voice acting, finished audio, or polished menus.

No verified Windows, Web or Android release package is recorded in this repository yet. The current workflow is configured for Web and Windows only. Android export still needs an Android preset, SDK/JDK setup, signing decisions and device testing. Do not describe the game as deployed or finished until a successful build artifact has been produced and tested.

## Next engineering milestones
1. Run the current GitHub Actions workflow and fix any GDScript, import or export errors until Web and Windows artifacts are produced.
2. Run the Web build in a browser and test movement, camera, dialogue, stage transitions and UI scaling.
3. Add an Android export preset, configure the Android SDK/JDK in CI, create a debug APK for testing, then test on real Android devices.
4. Replace procedural people with licensed rigged 3D human models and animations; add varied faces, hair, clothing, body proportions and animation retargeting.
5. Replace blockout buildings/grounds with detailed, optimised environments and lighting.
6. Add NPC navigation, schedules, reactions, memory, relationship progression and stage-specific activities.
7. Add missions and a progression/save system; profile performance on low-end Android devices.
8. Deploy the verified Web build to a static host only after the export succeeds.

## Controls currently intended
- WASD / arrow keys: move
- Mouse: rotate camera
- Shift: run
- Space: jump
- E: interact/talk
- N: next life stage
- Touchscreen: on-screen movement and action buttons; drag to rotate camera
