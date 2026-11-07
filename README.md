# Inescapable Prison

An isometric Godot 4 game where you play a villain locked in a prison nobody has ever escaped.

## How to play the starter build

1. Install **Godot 4** (4.3 or newer, the standard version, not .NET) from https://godotengine.org/download
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the ▶ play button in the top-right corner).
4. Wait for the earthquake, then walk with **WASD** or the **arrow keys** and slam enemies with **Space**.
5. Clear each level, then step on the green lift to go up. Four levels: Cell Block C, Mess Hall, Security Wing, and the Captain's Yard boss fight.
6. Lose all your health and you're **CONTAINED**: press **R** to retry the level.

## What's in here

| File | What it does |
| --- | --- |
| `scripts/main.gd` | Holds every level as a text map and runs the game: the earthquake opening, enemy waves, lifts, the boss, health and game over. Edit a map at the top to redesign a level. |
| `scripts/player.gd` | The villain: movement, the casing slam, breakable restraints, and how they're drawn. |
| `scripts/enemy.gd` | Prison guards and security robots that chase the villain. |
| `scripts/rig.gd` | The containment rig the villain starts in. |
| `scripts/boss.gd` | Captain Brask, the huge guard captain (first boss). |
| `scripts/lift.gd` | The lift pad between levels. |
| `scripts/plasma_bolt.gd`, `scripts/rifle_pickup.gd` | The plasma rifle the captain drops. |
| `scripts/block.gd` | Walls, cell bars, bunks, toilets and tables. |
| `scripts/floor.gd` | The isometric concrete floor. |

All art is drawn with simple shapes in code for now, so it can be swapped for real sprites later.
