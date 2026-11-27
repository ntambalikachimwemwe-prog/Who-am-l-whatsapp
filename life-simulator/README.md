# Life Journey — expanding 3D life simulation

Life Journey is a third-person 3D life-simulation project built with Godot 4. It follows a character through four different environments.

## Environments now included
- **Primary school:** school grounds, classroom desks, teacher, classmates, headteacher and a family home.
- **Secondary school:** boys' and girls' hostel blocks, dorm beds, a common room, roommates and friends.
- **University:** lecture block, lecture desks, student centre, library, lecturer, study partner, campus friends and a potential romantic interest.
- **Adult life:** neighbourhood road, home, office, shop, bus stop, neighbour, colleague, shopkeeper and partner.

The N key / NEXT button changes life stage and rebuilds the environment around the player. People can be approached and spoken to. The player types the character's words and receives simple rule-based replies.

## Controls
**Keyboard and mouse**
- WASD / arrow keys: move
- Mouse: look around
- Shift: run
- Space: jump
- E: talk to a nearby person
- N: change life stage
- Esc: release mouse capture

**Touchscreen**
- Direction buttons: move
- RUN: run while held
- JUMP: jump
- TALK: speak to a nearby person
- NEXT: change life stage
- Drag the game view to rotate the camera

## Run locally
1. Install Godot 4.3 or newer.
2. Import `life-simulator/project.godot` in Godot.
3. Press F6/F5 to run the main scene.

## Current limitations
This is a growing playable game foundation, not a finished photorealistic commercial game. People are still capsule-based 3D placeholders; environments use procedural geometric models and simple materials. Conversations are rule-based, characters do not yet walk around autonomously, and the game does not yet include missions, a full relationship system, save/load, voice, vehicles, or finished sound and music. Windows and Android release packages have not yet been generated and tested. A successful automated Godot validation is required before claiming a verified build.
