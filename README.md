# Inescapable Prison

An isometric Godot 4 game where you play a villain locked in a prison nobody has ever escaped.

## How to play the starter build

1. Install **Godot 4** (4.3 or newer, the standard version, not .NET) from https://godotengine.org/download
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the ▶ play button in the top-right corner).
4. Wait for the earthquake, then walk with **WASD** or the **arrow keys** and slam enemies with **Space**.

## What's in here

| File | What it does |
| --- | --- |
| `scripts/main.gd` | Builds the room from a text map and runs the opening (earthquake, alarm, enemies). Edit the map at the top to redesign the cell block. |
| `scripts/player.gd` | The villain: movement, the casing slam, breakable restraints, and how they're drawn. |
| `scripts/enemy.gd` | Prison guards and security robots that chase the villain. |
| `scripts/rig.gd` | The containment rig the villain starts in. |
| `scripts/block.gd` | Walls, cell bars, bunks, toilets and tables. |
| `scripts/floor.gd` | The isometric concrete floor. |

All art is drawn with simple shapes in code for now, so it can be swapped for real sprites later.
