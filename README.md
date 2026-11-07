# Inescapable Prison

An isometric Godot 4 game where you play a villain locked in a prison nobody has ever escaped.

## How to play the starter build

1. Install **Godot 4** (4.3 or newer, the standard version, not .NET) from https://godotengine.org/download
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the ▶ play button in the top-right corner).
4. Wait for the earthquake, then walk with **WASD** or the **arrow keys** and punch with a **left click** (toward the mouse), **Space** or **J**. Each punch hits everything in a 120-degree arc in front of you. Tap it fast for a jab, jab, heavy-hook combo.
5. Knocked-out enemies drop glowing XP. Each time you level up, the game pauses and offers three super-villain powers: press **1**, **2** or **3** (or click a card) to pick one.
6. The levels are big and the camera follows you. Clear every enemy, then step on the green lift to go up. Four levels: Cell Block C, Mess Hall, Security Wing, and the Captain's Yard boss fight.
7. Beat Captain Brask and grab his master key to open the lift down to **Solitary Confinement**.
8. In the Medical Wing, walk up to **Nurse Greta** and press **E** to get patched back to full health (once per visit).
9. Enemies drop packs of **smokes**. In Solitary, walk up to **Turkey** and press **E** to trade smokes for relics and powers (**1/2/3** buy, **R** restocks, **E** leaves).
10. Lose all your health and you're **CONTAINED**: press **R** to retry the level.

## What's in here

| File | What it does |
| --- | --- |
| `scripts/main.gd` | Holds every level as a text map and runs the game: the earthquake opening, enemy waves, lifts, the boss, health and game over. Edit a map at the top to redesign a level. |
| `scripts/player.gd` | The villain: movement, the punch combo, XP and super-villain powers, breakable restraints, and how they're drawn. |
| `scripts/level_up.gd` | The level-up screen with three power cards. |
| `scripts/xp_orb.gd` | The XP that enemies drop. |
| `scripts/enemy.gd` | Prison guards and security robots that chase the villain. |
| `scripts/rig.gd` | The containment rig the villain starts in. |
| `scripts/boss.gd` | Captain Brask, the huge guard captain (first boss). |
| `scripts/lift.gd` | The lift pad between levels. |
| `scripts/key_pickup.gd` | Captain Brask's master key. |
| `scripts/turkey.gd`, `scripts/shop.gd` | Turkey, the merchant in solitary, and his shop screen. |
| `scripts/greta.gd` | Nurse Greta in the Medical Wing. |
| `scripts/live_wire.gd` | Sparking live wires hanging from the ceiling. |
| `shaders/` | Effects: fog, scanlines, character squash and hit flashes, swaying pillars, rippling floors, jittering wires. |
| `scripts/block.gd` | Walls, cell bars, bunks, toilets and tables. |
| `scripts/floor.gd` | The isometric concrete floor. |

All art is drawn with simple shapes in code for now, so it can be swapped for real sprites later.
