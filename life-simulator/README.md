# Life Journey — 2D life simulation

Life Journey is being rebuilt as a **2D, photo-based life simulation** (not a 3D game). The player moves through illustrated locations and speaks to characters by typing dialogue.

## Life stages
- Primary school: classroom, teacher, classmates, school grounds and home.
- Secondary school: hostel, dormitory and common room conversations.
- University: lecture theatre, campus, student centre, friendships and respectful relationship conversations.
- Adult life: workplace, neighbourhood and home.

## Controls
- WASD or arrow keys: move
- E or TALK: speak to a nearby character
- NEXT LIFE STAGE: move to the next life stage

## Character photographs
The game supports approved character portrait files at:
- `life-simulator/assets/characters/player.png`
- `life-simulator/assets/characters/friend.png`
- `life-simulator/assets/characters/girlfriend.png`
- Other NPC portrait paths are listed in `scripts/life_journey_2d.gd`.

Until portrait files are added, the game draws simple 2D placeholder people. Only use a friend's recognizable photo after that person has agreed to its use. Do not use screenshots containing private chat/status UI as character portraits; use the original photo instead.

## Current release status
This is a 2D playable foundation, not yet a finished release. The 2D movement, stage scenes, proximity interaction, dialogue input and stage switching are implemented in the project source. The personal photographs still need to be cropped/prepared and added as game assets, then the project must pass a Godot export and be tested on an Android phone and/or browser before it can be called a finished product. No tested APK or deployed web build is claimed.
