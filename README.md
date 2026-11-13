# Bending Arena

A third-person elemental arena duel for the CSE 310 games module, built in
**Godot 4 (GDScript)**. Pick fire, water, earth or air, fight an AI bender in
best-of-3 rounds, earn skill points and spend them in each element's skill
tree. Each element has six moves (a three-hit basic combo plus five
unlockable moves), every shot follows your aim up and down, and the fighters
are stick figures with procedural animation. Everything is built from
primitives and particles: no imported models, animations or audio.

**Demo video:** (add the link here after recording)

## Play without Godot

The standalone builds need nothing installed:

- **Windows:** run `BendingArena.exe`. If SmartScreen warns about an unknown
  app, click **More info**, then **Run anyway**.
- **Mac:** unzip `BendingArena-mac.zip` and open **Bending Arena.app**. It isn't
  notarized by Apple, so the first time right-click it and choose **Open**
  (on newer macOS: try to open it once, then **System Settings > Privacy &
  Security > Open Anyway**). It runs natively on Apple Silicon and Intel.

To make them yourself: install the Godot 4.4.1 export templates (Editor >
Manage Export Templates), then **Project > Export** and pick "Windows Desktop"
or "macOS" (the presets are in `export_presets.cfg`), or from a terminal:

```
godot --headless --path . --export-release "Windows Desktop" builds/BendingArena.exe
godot --headless --path . --export-release "macOS" builds/BendingArena-mac.zip
```

## Run it in the editor

1. Install Godot 4.4 or newer (standard build, not .NET) from godotengine.org.
   Tested with 4.4.1.
2. In the Project Manager choose **Import**, pick this folder's `project.godot`,
   then **Import & Edit**.
3. Press **F5** (Run Project). The game starts on the title screen
   (`scenes/menu.tscn`).

The first open builds the `.godot/` cache, which is git-ignored.

## How to play

- **Title screen:** pick your element, the opponent (random or a set element)
  and the difficulty, then **Fight**, **Training** or **Skill Trees**.
- **Fight:** best of 3 rounds against an AI bender, 90 seconds a round. Knock
  them out to take the round; if the clock runs out, whoever has more of their
  HP left wins it. Winning a round earns 1 skill point, winning the match 2 more.
- **Training:** a training dummy, no clock, every move unlocked so you can try
  them before you buy. Keys 1 to 4 switch element on the fly.
- **Skill Trees:** one tree per element, six nodes each. The basic attack is
  always yours; the tree unlocks the special, utility and ultimate and
  upgrades them. **Reset tree** refunds every point in that tree. You start
  with 3 points.
- Progress (points, unlocks, last picks, match record) saves to
  `user://save.json` automatically.

## Controls

| Action | Input |
| --- | --- |
| Move | W A S D or arrow keys (relative to the camera) |
| Sprint | Shift |
| Jump | Space |
| Aim / orbit camera | Mouse (shots go toward the crosshair, up and down too, with a light aim assist) |
| Basic attack | Left mouse (hold to repeat; every third hit is a stronger finisher) |
| Special | Right mouse |
| Heavy | E |
| Defense | F |
| Utility | Q |
| Ultimate | R |
| Pause menu | Esc or P |
| Hide the controls help | H |
| Switch element (training only) | 1 2 3 4 |

Input actions are registered at startup by `scripts/controls.gd` (autoload
`Controls`). Any action you define in **Project Settings > Input Map** takes
priority, so you can move them there whenever you like.

## The four elements

| Element | HP | Basic (LMB) | Special (RMB) | Heavy (E) | Defense (F) | Utility (Q) | Ultimate (R) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Fire | 125 | Fire Jabs: jab, jab, flame kick (a burning crescent) | Flame Breath: cone of fire | Fireball: explodes on impact | Fire Ring: spin a ring of fire that burns and stops shots | Jet Dash: fire-propelled dash, can't be hit | Lightning: charge, then an instant bolt where you aim |
| Water | 132 | Water Whip: lash, lash, wide water slice; slows | Ice Daggers: three fast shards | Ice Prison: freezes the target in place | Ice Wall | Healing Water: heal 30 over 4 s | Tidal Wave: rolls along the ground through everything |
| Earth | 165 | Rock Throw: rocks pulled from the ground, third throw is three at once | Earth Column: pillar bursts up where you aim and launches | Fissure: line of spikes along the ground, knocks up and slows | Stone Wall | Rock Armor: stomp, then half damage for 5 s | Boulder Barrage: three boulders ripped out of the ground |
| Air | 135 | Air Blast: short, wide, shoves; third blast shoves hard | Air Cannon: fast ball of air | Air Blade: thin slice that cuts through | Air Shield: sphere that stops shots and pushes enemies away | Air Scooter: ride a ball of air, faster with higher jumps | Tornado: drags enemies in |

Everything but the basic costs chi (the blue bar), which refills over
time. Every number (damage, cooldowns, chi costs, speed, range, HP, round
length, points, AI difficulty) lives in `data/balance.json`; the trees live in
`data/skill_trees.json`. Change them there, no code needed.

## Class requirements

| Requirement | Where it is |
| --- | --- |
| Display a background | Procedural sky, distant mountains and outer ground in `scenes/arena.tscn` |
| At least 1 un-movable object | Arena walls, stone pillars and Stone Walls (`StaticBody3D`) |
| At least 1 movable object | The player and the AI opponent (`CharacterBody3D`), projectiles, tornadoes |
| Collisions of at least 2 objects | Benders against floor, walls, pillars and each other (`move_and_slide`); projectiles hitting benders, the dummy and walls (`Area3D.body_entered`) |
| Keyboard or mouse input | WASD, Shift, Space, E, F, Q, R, Esc, mouse look and mouse buttons |
| Stretch: save and load | `scripts/game.gd` saves skill points and unlocks to `user://save.json` and loads them at startup |

## How it's built

```
project.godot
export_presets.cfg      # Windows and macOS export settings
data/
  balance.json          # every tunable number, and each ability's type and stats
  skill_trees.json      # six nodes per element: unlocks, stat mods, passives
scenes/
  menu.tscn             # title screen (arena backdrop + main_menu.gd)
  skill_tree.tscn       # skill tree screen
  main.tscn             # the fight: arena, player, HUD, round manager, pause menu
  arena.tscn            # sky, sun, floor, walls, invisible barriers, pillars, backdrop
  player.tscn           # your bender: body, Health, Chi, Abilities, camera rig
  opponent.tscn         # AI bender: same body plus a name tag
  projectile.tscn       # one shot (Area3D)
  training_dummy.tscn   # static target in group "targets"
  stone_pillar.tscn     # arena pillar
scripts/
  controls.gd           # autoload: input actions
  balance.gd            # autoload: reads balance.json
  game.gd               # autoload: picks, skill points, tree logic, save/load
  bender.gd             # shared body for player and AI: element, abilities,
                        #   movement, slows, knockback, dashes, healing
  player.gd             # keyboard/mouse, camera, crosshair aim
  ai_bender.gd          # feeds AiBrain into the shared body
  ai_brain.gd           # AI: range keeping, strafing, aim lead, move choice
  stick_figure.gd       # the fighters' bodies and procedural animation
  health.gd, chi.gd     # HP and chi components with signals
  abilities/            # Ability base + projectile, cone, beam, pillar, fissure,
                        #   wall, shield, dash, boost, heal, area, tornado
  projectile.gd         # shots and their looks (fire, water, ice, rock, air, wave)
  fissure.gd, shield.gd, tornado.gd   # moving parts of those moves
  effects.gd            # particles, lights, crescents, lightning, spikes, rings
  round_manager.gd      # rounds, clock, scoring, results, training mode
  hud.gd, pause_menu.gd, main_menu.gd, skill_tree.gd, ui.gd   # screens, built in code
tests/
  smoke_test.gd         # automated playthrough (see below)
```

How a move works: when you pick an element, `Bender.apply_element()` reads
`elements.<element>.abilities` from `balance.json`, makes one ability node per
slot your tree has unlocked (the `type` field picks the script: projectile,
cone, beam, pillar, fissure, wall, shield, dash, boost, heal, area or
tornado), and applies the tree's stat mods on top. Each ability checks its
cooldown and chi in `try_activate()` and then does its thing in `_activate()`.
A hit is one Dictionary (`damage`, `direction`, `knockback`, `slow`,
`slow_time`, `root_time`, `launch`) passed to `take_hit()`. A `combo` list on
the basic makes it a chain; `look` picks how a shot is drawn (`projectile.gd`)
and `anim` the pose the stick figure strikes.

How the fighters work: `scripts/stick_figure.gd` builds the body from thin
capsules (spine, arms, legs, head, glowing hands, an element-coloured band and
sash) and poses every joint each frame: a fighting stance, a run cycle from
the body's speed, a tuck in the air, and a short action pose (punch, kick,
push, sweep, raise, stomp, spin, ride, channel, hit) blended on top when a move
is used. Arms in punches and pushes follow the aim pitch.

Effects are built in `scripts/effects.gd` from CPU particles, lights and
generated meshes (crescents, the wave, lightning segments, spikes), so there
are no textures or imported assets.

How the camera works: `CameraPivot` turns left and right with the mouse,
`SpringArm3D` tilts up and down and pulls the camera in when a wall is behind
you, and the arm sits over your right shoulder (move `SpringArm3D` on X to change
that). Shots go from your chest toward whatever is under the crosshair (a ray
from the camera), so aiming up or down sends them up or down. Ground moves
(Earth Column, Fissure, walls, Tidal Wave, Tornado) use the flat part of the
aim; Earth Column lands where the crosshair meets the floor.

The AI: `AiBrain` thinks every `reaction` seconds (0.45 s on Easy, 0.15 s on
Hard). Each element has a range it likes to fight at; it closes or backs off to
that range, strafes, hops when stuck on a pillar, leads its shots (aiming at
your chest, so jumping doesn't dodge everything), and uses its other moves when
they make sense (shield or wall when your shots are incoming, heal or armor
when hurt, scooter to close distance). Difficulty also sets its aim error and
which skill-tree nodes it has (Easy: special only; Normal: special, heavy and
utility; Hard: everything).

Physics layers: 1 world, 2 benders, 3 targets. Projectiles watch all three.

## Testing

`tests/smoke_test.gd` plays the game by itself: it opens every screen, buys and
refunds skill-tree nodes, checks save and load, runs training, plays a full
Hard match for each element with your bender on autopilot, and checks the pause
menu. From this folder, with Godot on your PATH:

```
godot --headless --fixed-fps 60 --path . -- --smoke
```

It prints `SMOKE: PASS` and exits 0, or lists what failed and exits 1. It uses
its own save file, so your progress is untouched. `--quick` plays one match
instead of four; `--balance` plays every element against every other and
prints round wins, which is how the starting numbers were tuned.

## Future work

- Sound effects and music (CC0 or original)
- Local two-player split screen or online play
- More arenas, with terrain each element can use (water pools, loose rock)
- Controller support and rebindable keys in an options menu
- Signed and notarized builds so Windows and macOS don't warn on first launch

## Assets and IP

This is a fan project for class. The repo has no show models, music, logos or
character names: generic names like "Waterbender", original move names, and
primitive shapes only. Credit any CC0 assets here if you add some.
