# Bending Arena

A third-person elemental arena duel for the CSE 310 games module, built in
**Godot 4 (GDScript)**. Placeholder primitives only: capsules, boxes and
cylinders, no imported models or animations.

## Run it

1. Install Godot 4.4 or newer (standard build, not .NET) from godotengine.org.
2. In the Project Manager choose **Import**, pick this folder's `project.godot`,
   then **Import & Edit**.
3. Press **F5** (Run Project). The main scene is `scenes/main.tscn`.

The first open builds the `.godot/` cache, which is git-ignored.

## Controls

| Action | Input |
| --- | --- |
| Move | W A S D (relative to the camera) |
| Sprint | Shift |
| Jump | Space |
| Look / orbit camera | Mouse |
| Free the mouse | Esc (click the window to grab it again) |
| Reserved for abilities | Left / right mouse button (`attack_basic`, `attack_special`) |

Input actions are registered at startup by `scripts/controls.gd` (autoload
`Controls`). Any action you define in **Project Settings > Input Map** takes
priority, so you can move them there whenever you like.

## Class requirements

| Requirement | Where it is |
| --- | --- |
| Display a background | Procedural sky, distant mountains and outer ground in `scenes/arena.tscn` |
| At least 1 un-movable object | Arena walls and stone pillars (`StaticBody3D`) |
| At least 1 movable object | The player (`CharacterBody3D`) |
| Collisions of at least 2 objects | Player against floor, walls, pillars and the training dummy (`move_and_slide`) |
| Keyboard or mouse input | WASD, Shift, Space and mouse look |
| Stretch: save and load | Planned for session 5 (skill tree unlocks to `user://save.json`) |

## Layout

```
project.godot
scenes/
  main.tscn            # arena + player + training dummy + HUD
  arena.tscn           # sky, sun, floor, walls, pillars, backdrop
  player.tscn          # CharacterBody3D, Model, CameraPivot > SpringArm3D > Camera3D
  stone_pillar.tscn    # reusable StaticBody3D (earth wall ability can spawn these)
  training_dummy.tscn  # static target in group "targets"
scripts/
  controls.gd          # autoload: input actions
  player.gd            # movement, jump, sprint, orbit camera, respawn
  hud.gd               # controls hint + FPS
data/
  balance.json         # every tunable number (HP, speed, chi)
```

How the camera works: `CameraPivot` turns left and right with the mouse,
`SpringArm3D` tilts up and down and pulls the camera in when a wall is behind
you, and movement follows the pivot's yaw so W always means "away from the
camera". The body (`Model`) turns to face the way you move. Tune speeds,
jump, sensitivity and pitch limits in the Inspector on the `Player` node.

## Build sessions

1. Open the base, learn the editor, tune movement and camera
2. Projectiles, hits on the training dummy, HP and rounds
3. Ability system (cooldown, chi) and a basic attack for all four elements
4. Specials and utilities; simple AI opponent
5. Skill trees and save/load (stretch)
6. Balance, polish, README, demo video, submit

## Assets and IP

This is a fan project for class. Keep the repo free of ripped show models,
music, logos or character names; use original or CC0 assets and generic names
like "Waterbender", and credit any CC0 assets here.
