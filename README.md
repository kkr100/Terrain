# Terrain

A learning prototype of an offroad driving game, inspired by games like
"Over the Hill". It's built with [Godot 4](https://godotengine.org/), a free
and open source game engine.

Pick one of three cars, a light rally hatch, a trail SUV or a heavy pickup,
and drive it across hilly offroad country with dirt, mud and rock, each with
its own grip. There are two ways to play:

- **Point to point:** pick one of three levels, then drive through every
  checkpoint and the finish line, in order, as fast as you can. **Green
  Valley** (easy) is gentle green hills, **Mud Marsh** (medium) is flat,
  grey and half deep mud, and **Rocky Ridge** (hard) is steep and rocky, at
  sunset. The game remembers your best time on each level with each car.
- **Explore:** roam a huge map, 2.5 km across (ten times wider than the race
  map), and find 12 hidden places: a campsite, an old wreck, a lookout tower,
  standing stones and more. The game remembers which ones you found.

## How to open and run it

1. Download **Godot 4.5 or newer** (the standard version, not .NET) from
   <https://godotengine.org/download>. It's a single program, no installer needed.
2. Clone this repository, or download it as a ZIP and unpack it.
3. Start Godot. In the Project Manager, click **Import**, pick the
   `project.godot` file in this folder, then click **Import & Edit**.
4. Press **F5** (or the ▶ play button in the top right) to run the game.
   The main menu opens. Click **Point to point** (then pick a level) or
   **Explore** (or press Enter), pick a car, then click **Drive!**.
   Close the window or press **F8** to stop it.

Want to skip the menu while you're working on the map or the car? Open
a level in `scenes/levels/` (a race) or `scenes/explore.tscn` (Explore) and press
**F6** (or the "Run current scene" button). That runs just the scene you have
open.

## How to play

After a "3, 2, 1, GO!" countdown, drive to the **bright yellow beam of
light**. That's the next checkpoint. Drive through the ring at its foot and
the beam moves on to the next one. The faint white beams show where the
later checkpoints are, so you can plan your route. The last one, the
**finish**, glows green.

The top-right corner shows which checkpoint you're on, how far away it is,
and your time. There's no road: pick your own way over the hills, and watch
out for mud, which is slippery and slow. If you fall off the world, you're
put back at the last checkpoint you passed.

## Controls

You can play with the keyboard or a game controller (Xbox, PlayStation 4/5,
or most others that work on your computer). Just plug it in, or pair it over
Bluetooth, before or while the game runs. The hints at the bottom of the
screen switch to the controller's buttons as soon as you press one, and back
to keys when you touch the keyboard.

### Keyboard

| Key | What it does |
| --- | --- |
| **W** or **↑** | Drive forward |
| **S** or **↓** | Brake. Once you've stopped, hold it to reverse. |
| **A D** or **← →** | Steer |
| **Space** | Handbrake |
| **R** | Flip the car back onto its wheels |
| **Shift** | Nitro boost (once you've fitted the Nitro upgrade) |
| **M** | Open or close the map (Explore mode) |
| **Esc** or **P** | Pause (and unpause) |
| **`** (left of 1) or **F1** | Open or close the hidden dev console (see below) |

### Controller

| Xbox | PlayStation | What it does |
| --- | --- | --- |
| **RT** | **R2** | Drive forward. Squeeze it gently for less power. |
| **LT** | **L2** | Brake. Once you've stopped, hold it to reverse. |
| **Left stick** or **D-pad ← →** | **Left stick** or **D-pad ← →** | Steer (the stick steers gently or hard, depending on how far you push it) |
| **Right stick** | **Right stick** | Look around the car |
| **Click the right stick** | **R3** | Look behind you |
| **A** | **Cross** | Handbrake |
| **Y** | **Triangle** | Flip the car back onto its wheels |
| **X** or **RB** | **Square** or **R1** | Nitro boost (once you've fitted the Nitro upgrade) |
| **View** (the small left button) | **Create** | Open or close the map (Explore mode) |
| **Menu** (the small right button) | **Options** | Pause (and unpause) |

In the menus, move with the **left stick** or the **D-pad**, press **A** /
**Cross** to choose, and **B** / **Circle** to go back (or to close the
pause menu, the map, or an upgrade list). On the level- and car-select
screens, left and right flip through the levels or cars, and up and down
reach the upgrade slots. The dev console needs a keyboard.

The map is surrounded by steep rock walls. If the car ever falls through the
world, it's put back at the start.
The keys and controller buttons live in **Project > Project Settings > Input
Map**, so you can change them there without touching any code.

### The dev console

For testing there's a hidden console. Press the key just left of **1**
(that's **`** on most keyboards and **§** on Swedish and other Nordic ones),
or **F1**, on any screen. The game freezes while it's open. Type a command and
press **Enter**:

| Command | What it does |
| --- | --- |
| `help` | Lists the commands. |
| `unlock_all` | Unlocks all 12 upgrades, so you can fit them on the car-select screen without exploring. |
| `relock` | Undoes `unlock_all`. Upgrades from places you really found stay unlocked. |
| `upgrades` | Lists every upgrade and whether it's unlocked. |
| `clear` | Empties the console. |

**↑** and **↓** bring back commands you typed before, and **Esc** closes it.
`unlock_all` doesn't pretend you found any places: it's a separate switch
(`unlock_all` in the `[dev]` section of `user://save.cfg`), so your Explore
progress stays as it was.

The first time you open the project Godot takes a moment to "import" it. It
creates a hidden `.godot/` folder as a cache. That folder is ignored by git,
so you never need to commit it.

## What's in the project

| File | What it is |
| --- | --- |
| `project.godot` | The project's settings: its name, window size, and which scene starts first. Godot edits this for you when you change **Project > Project Settings**. |
| `export_presets.cfg` | The settings for making a Windows, Linux or macOS build. See "Making a desktop build" below. |
| `scenes/main_menu.tscn` | The main menu, the first thing that loads when the game runs. |
| `scenes/race_base.tscn` | Everything a race needs: the sky, the map, the car, the camera and the HUD. Every level is built on top of it. |
| `scenes/levels/` | The three point-to-point levels. Each one changes the terrain, the sky and the checkpoints of `race_base.tscn`. |
| `scenes/level_select.tscn` | The level-select screen, with a map of each level and its route. |
| `scenes/explore.tscn` | Explore mode: the big map, the points of interest, the camera and its HUD. |
| `scenes/poi/` | The 12 points of interest, one small scene each. |
| `scenes/checkpoint.tscn` | One checkpoint (a beam of light and a ring). Each level uses it 9 to 12 times. |
| `scenes/pause_menu.tscn` | The menu that shows when you press Esc. |
| `scenes/car_select.tscn` | The car-select screen, with a 3D preview of each car. |
| `scenes/cars/rally.tscn`, `suv.tscn`, `pickup.tscn` | The three cars: model, wheels, suspension, engine sound, and the spots where upgrade parts go. |
| `upgrades/` | The 12 car upgrades, one `.tres` file each. |
| `scenes/upgrade_parts/` | The parts you can see on an upgraded car: the rally wing, the roof light bar and the nitro exhaust. |
| `scripts/car.gd` | Used by all three cars. Reads the keyboard or controller and tells the car to drive, brake and steer. |
| `scripts/engine_sound.gd` | Plays each car's engine noise from recorded loops, following the RPM. |
| `scripts/car_choice.gd` | The list of cars (names, descriptions, stat bars) and which one you picked. |
| `scripts/car_spawner.gd` | Puts the car you picked, with its upgrades, into the race. |
| `scripts/car_upgrade.gd` | Describes one upgrade: its slot, which place unlocks it, and how it changes the car. |
| `scripts/upgrades.gd` | The list of upgrades, which ones you've unlocked, and which are fitted to each car. |
| `scripts/nitro_flames.gd` | Shows the nitro flames while you boost. |
| `scripts/car_select.gd` | Makes the car-select screen work, including fitting upgrades. |
| `scripts/chase_camera.gd` | Makes the camera follow the car from behind, and look around with the right stick. |
| `scripts/controls.gd` | Knows whether you're using the keyboard or a controller (Xbox or PlayStation), so the HUD shows the right buttons. An autoload. |
| `scripts/hud.gd` | Shows the speed, the race info, the countdown and the finish screen. |
| `scripts/race.gd` | The game rules: countdown, timer, which checkpoint is next, the finish. |
| `scripts/checkpoint.gd` | Notices when the car drives through a checkpoint, and changes its colour. |
| `scripts/best_time.gd` | Saves and loads your best time on each level with each car. |
| `scripts/level_choice.gd` | The list of levels (names, difficulty, descriptions) and which one you picked. |
| `scripts/level_select.gd` | Makes the level-select screen work. |
| `scripts/level_map.gd` | Draws a level's map and route on the level-select screen. |
| `scripts/main_menu.gd` | Makes the mode buttons and Quit work. |
| `scripts/game_mode.gd` | The list of modes, and which one you picked. |
| `scripts/explore_terrain.gd` | Builds the big Explore map in chunks, with less detail far away. |
| `scripts/explore_nature.gd` | Trees, rocks and bushes on the big map, built around the car. |
| `scripts/nature_models.gd` | Shared helpers for loading and repainting Kenney's nature models. |
| `scripts/point_of_interest.gd` | One place to discover: its name, description and how close you must get. |
| `scripts/tint_model.gd` | Tints a model, for example to make a car look rusty. |
| `scripts/exploration.gd` | Explore mode's rules: notices when you find a place, and saves it. |
| `scripts/explore_hud.gd` | Explore mode's HUD: speed, places found, the "Discovered!" and "Upgrade unlocked!" messages. |
| `scripts/compass.gd` | The compass strip at the top of the screen in Explore mode. |
| `scripts/explore_map.gd` | The map screen (M) in Explore mode. |
| `scripts/dev_console.gd` | The hidden dev console (the **`** key). It's an autoload, so it's on every screen. |
| `scripts/pause_menu.gd` | Pauses the game and makes the pause menu's buttons work. |
| `scripts/terrain.gd` | Builds the hills, paints the dirt, mud and rock, and tells the car which surface is under a wheel. |
| `scripts/surface_type.gd` | Describes one kind of ground: its name, grip, drag and colour. |
| `scripts/nature.gd` | Scatters trees, rocks and bushes over the map, away from the start and the route. |
| `shaders/terrain.gdshader` | Paints the terrain in a flat-shaded, low-poly cartoon style. |
| `materials/terrain.tres` | The terrain's material: the colours of dirt, mud and rock. |
| `assets/models/` | Low-poly cars and nature models (CC0, from Kenney). |
| `assets/CREDITS.md` | Where every model comes from, and its license. |
| `.gitignore` | Tells git to skip Godot's generated cache files. |
| `.gitattributes` | Keeps line endings consistent across Windows, macOS and Linux. |

## Godot basics in two minutes

Everything in Godot is built from **nodes**. A node is one thing with one job:
a light, a camera, a 3D model, a sound. Nodes are arranged in a tree, and a
saved tree of nodes is called a **scene** (a `.tscn` file). A scene can be a
whole level, or something small like a car that you reuse inside other scenes.

Open `scenes/levels/green_valley.tscn` and look at the **Scene** panel on the
left. It shows this tree:

```
GreenValley (Node3D)       the root; every other node hangs under it
├── WorldEnvironment       the sky and overall lighting look
├── Sun (DirectionalLight3D)  sunlight coming from one direction, with shadows
├── Terrain (StaticBody3D)  the hilly ground; scripts/terrain.gd builds it
├── CarSpawner (Marker3D)   puts the car you picked here when the race starts
├── ChaseCamera (Camera3D) what the player sees; it follows the car
├── Checkpoints (Node3D)   holds Checkpoint1 … Checkpoint8 and Finish
├── Race (Node)            the rules; scripts/race.gd
├── HUD (CanvasLayer)      2D text and the finish screen, drawn on top of the 3D world
└── PauseMenu              an instance of scenes/pause_menu.tscn
```

Click any node and its settings show up in the **Inspector** on the right.
Try it: select `Sun` and change its rotation. Press F5 again to see the result.

Some useful things to know:

- **Units are meters.** One unit in Godot equals one meter, which matters
  once physics and cars arrive.
- **Y is up.** The ground lies flat on the X and Z axes.
- **Seeing and touching are separate.** A `MeshInstance3D` is only a picture.
  Physics only knows about `CollisionShape3D` nodes. That's why the terrain
  makes both. If you add a new obstacle, give it both or the car drives through it.
- **Moving around in the editor:** hold the right mouse button and use
  W A S D to fly around the 3D view.

## How the cars work

There are three cars in `scenes/cars/`. Open `scenes/cars/suv.tscn` to see
one on its own:

```
Car (VehicleBody3D)        the physics body; scripts/car.gd is attached here
├── CollisionShape3D       a box, the shape that bumps into things
├── Model                  the 3D model (a .glb file), just looks, no physics
├── WheelFrontLeft … WheelRearRight (VehicleWheel3D)
└── EngineSound (Node)     the engine noise; scripts/engine_sound.gd
```

All three use the same script. What makes them feel different is only
numbers: the mass, the engine power, the top speed, how far the wheels steer,
and the wheel settings below. Select the root `Car` node of each one and
compare them in the Inspector.

| | Rally Hatch | Trail SUV | Heavy Pickup |
| --- | --- | --- | --- |
| Mass | 850 kg | 1400 kg | 2200 kg |
| Top speed | 145 km/h | 120 km/h | 105 km/h |
| Suspension | short and stiff | medium | long and soft |
| Tyres | small, very grippy | chunky | huge |
| In mud | slows down a lot (`mud_drag_scale` 1.6) | normal (1.0) | barely slows (0.45) |
| Engine | 4-cylinder, revs to 7500 | 6-cylinder, revs to 6000 | V8, revs to 4800 |

The models come from Kenney's free [Car Kit](https://kenney.nl/assets/car-kit)
(see `assets/CREDITS.md`). Each model has its wheels as separate parts called
`wheel-front-left` and so on. When the game starts, `car.gd` moves each one onto
the `VehicleWheel3D` with the matching name, so the tyres spin, steer and
bounce. The red rally car and blue pickup are recoloured with a copy of the
model's colour texture (the `paint` setting).

A trick worth knowing: each car's **center of mass** (on the root node, under
**Mass Distribution**) is set very low, near the ground. Real cars are
top-heavy and roll over in tight turns, and with Godot's simple car physics
they roll over far too easily. Moving the center of mass down makes them
stable. Try raising it to 0.5 and taking a sharp turn at speed!

### The engine sound

The engine noise comes from real recordings of a 4-cylinder, a 6-cylinder and
a V8 engine. `tools/make_engine_loops.py` cut them into short **loops** in
`sounds/engines/`: about a second of the engine at one steady RPM, cut so
the end flows straight into the start. Each car has 7 or 8 of them, from idle
to the redline (the number in the file name is the RPM).

`engine_sound.gd` plays the two loops closest to the engine's RPM at the same
time and blends between them, and speeds each one up or down a little
(`pitch_scale`) so it matches the RPM exactly. `car.gd` works out the RPM and
gear from the speed, like an automatic gearbox, and the HUD shows both.
With your foot off the pedal a **low-pass filter** (an audio effect that
turns down the high, sharp parts of a sound) muffles the engine, and when
the gearbox changes up the throttle is cut for a moment, like a real gear
change.

Select a car's `EngineSound` node and try `volume_db` and
`coasting_cutoff_hz` (lower is more muffled when you let go of the pedal).
While the game runs, the **Audio** tab at the bottom of the editor shows the
engine's own bus with the filter on it.

### The physics

**VehicleBody3D** is a physics body (a `RigidBody3D`) that Godot already knows
how to treat as a car. It has three settings a script changes every frame:

- `engine_force` pushes the car forward (negative values reverse).
- `brake` slows the wheels down.
- `steering` turns the front wheels, in radians.

**VehicleWheel3D** is where the suspension lives. A wheel is not a physics
object. Each wheel shoots an invisible ray straight down. If the ray hits the
ground, the wheel acts like a spring that pushes the car up. Select a wheel and
try these in the Inspector:

| Setting | What it does |
| --- | --- |
| `wheel_radius` | Size of the wheel. Keep it the same as the tyre you see. |
| `wheel_rest_length` | How long the spring is when nothing presses on it. |
| `suspension_travel` | How far the spring can squash. |
| `suspension_stiffness` | Spring strength. Low = soft and bouncy, high = stiff. |
| `damping_compression` / `damping_relaxation` | Shock absorbers: they stop the car bouncing forever. |
| `wheel_friction_slip` | Grip. Low numbers make the car slide, which is fun offroad. |
| `use_as_traction` / `use_as_steering` | Whether the engine drives this wheel / whether it steers. All four drive, only the front two steer. |

**Forward is +Z.** A `VehicleBody3D` drives towards its blue Z arrow. That's
why the front of each model points along +Z.

**The script** `scripts/car.gd` runs `_physics_process` 60 times a second. It
reads the keys with `Input.get_axis(...)` and sets `engine_force`, `brake` and
`steering`. The numbers at the top marked `@export` show up in the Inspector
when you select the car, so you can tune the top speed or engine power without
editing code.

**Which car is in the race?** The levels don't contain a car. Instead the
`CarSpawner` node asks `CarChoice` which car you picked, loads that scene,
and puts it at its own position. Then it tells the camera, the race and the
HUD which car to follow.

**The camera** in `scripts/chase_camera.gd` works out a spot behind and above
the car, then each frame moves only part of the way there. That lag is what
makes it feel smooth. Try changing `follow_speed` and `distance` on the
`ChaseCamera` node.

### Things to try

- Make a car slide more: lower `wheel_friction_slip` on all four wheels.
- Make it rear-wheel drive: untick `use_as_traction` on the front wheels.
- Make a monster truck: raise `tire_scale` on the Car node and `wheel_radius`
  on the wheels by the same amount, and raise `wheel_rest_length`.
- Raise `max_engine_force` on the Car node and launch off a hilltop.
- Add a fourth car: duplicate `scenes/cars/suv.tscn`, change its numbers (or
  swap the Model for another car from the Kenney kit), and add it to the
  `CARS` list in `scripts/car_choice.gd`.

### Upgrades

Every point of interest in Explore mode has a car upgrade hidden there. Find
the place and you unlock its upgrade ("Upgrade unlocked!" pops up after
"Discovered!"). Then fit it on the car-select screen, in the **Upgrades**
list under the stat bars. A car has four slots, and each slot holds one
upgrade, so you have to choose:

| Slot | Upgrades (and where to find them) |
| --- | --- |
| Engine | Tuned engine (campsite), Turbocharger (supply cache), Crawler gearbox (tractor) |
| Tyres | Rally tyres (wreck), All-terrain tyres (woodcutter's camp), Mud tyres (fishing pond) |
| Suspension | Rally suspension (standing stones), Anti-roll bars (ancient oak), Lift kit (lookout tower) |
| Body | Lightweight panels (mushroom grove), Rally wing (obelisk), Nitro boost (stone head) |

Each car remembers its own upgrades, and they work in both modes. The green
and red numbers next to the stat bars show how the fitted upgrades change
the car.

**How it works.** Each upgrade is a small file in `upgrades/` made from
`scripts/car_upgrade.gd`, a custom Resource just like the surfaces. Open
`upgrades/turbo.tres` and look in the Inspector: `unlocked_by` is the id of
the place that unlocks it, and the numbers say how it changes the car. They
don't replace the car's own numbers, they change them: `power_scale = 1.25`
means "25% more power than this car had", so the little rally car and the big
pickup both get faster, but still feel different.

There's nothing extra in the save file for unlocking: `scripts/upgrades.gd`
just checks which places you've found. It does save which upgrades are fitted
to which car, in the `[upgrades]` section of `user://save.cfg`.

When a race or Explore starts, `CarSpawner` hands the car its upgrades
*before* adding it to the scene. Then the car's `_ready` (in `car.gd`) goes
through them in `_apply_upgrade` and changes its settings: more engine force,
bigger wheels, longer springs, less weight, and so on. A few upgrades also do
something while you drive: the tyres change the grip in `_apply_ground`, the
wing pushes the car down harder the faster you go, and the nitro gives extra
power while you hold Shift, until the tank runs dry (the HUD shows how full
it is).

**The parts you can see** are tiny scenes in `scenes/upgrade_parts/`, built
from plain boxes and cylinders in the same low-poly style as the Kenney
cars. Each car scene has a `Mounts` node with three `Marker3D`s, `Roof`,
`Rear` and `Exhaust`, placed by hand to fit that car's shape. An upgrade's
`part_mount` says which one its part goes on. Mud tyres don't need a part:
they just make the wheels bigger.

To make your own upgrade: duplicate a `.tres` in `upgrades/`, give it a new
`id`, name and numbers, set `unlocked_by` to a place's id, and add its path to
`PATHS` at the top of `scripts/upgrades.gd`.

## How the terrain works

Select the `Terrain` node in a level, like `scenes/levels/green_valley.tscn`. Its script,
`scripts/terrain.gd`, builds the whole map from code when the game starts.
It does four things:

1. **Heights from noise.** It lays a grid over the map, one point per metre
   (256 × 256 m). For each point it asks a `FastNoiseLite` for a number.
   Noise is "smooth randomness": points next to each other get similar
   values, so together they make rolling hills instead of spiky chaos.
2. **A flat start and walls.** The middle is flattened so the car starts on
   calm ground, and the edges are raised into steep walls so you can't drive
   off the map.
3. **Surfaces.** Each point gets a surface. Steep slopes become rock. A second
   noise picks out patches of mud. Everything else is dirt.
4. **Mesh and collision.** The grid becomes an `ArrayMesh` (what you see)
   and a `HeightMapShape3D` (what the wheels touch).
   A height map shape is a collision shape made for terrain: just a grid of
   heights, which is exactly what we have.

The script starts with `@tool`, which means it also runs inside the editor,
so you see the hills there too. Change a setting in the Inspector, then click
**Regenerate** at the top of the Terrain's Inspector to rebuild it.

| Setting | What it does |
| --- | --- |
| `map_seed` | Any number gives a different map. Try a few! |
| `hill_height` | How tall the hills are, in metres. |
| `hill_frequency` | Small = wide, gentle hills. Big = lots of small, steep ones. |
| `spawn_flat_radius` | Size of the flat start area. |
| `edge_wall_height` | Height of the walls around the map. |
| `rock_slope_degrees` | Slopes steeper than this are rock. |
| `mud_amount` | Lower numbers make more mud. |

### Surfaces and grip

Each surface is a small **Resource** (`scripts/surface_type.gd`): a bundle
of settings you edit in the Inspector, just like a material. On the Terrain
node, open `Dirt`, `Mud` or `Rock` to change them:

| Surface | Grip | Drag | How it feels |
| --- | --- | --- | --- |
| Dirt | 1.0 | 0 | The normal, everyday ground. |
| Mud | 0.45 | 0.35 | Slippery and slow. The car slides when you steer and bogs down. |
| Rock | 1.4 | 0 | Grippy, which helps on the steep climbs where it appears. |

Every physics frame, `car.gd` checks each wheel. `wheel.get_contact_body()`
says what the wheel is touching. If it's the terrain, the car asks
`get_surface_at(...)` which surface is under that wheel, then sets the
wheel's `wheel_friction_slip` to its normal value times the surface's
`grip`. Mud's `drag` also pushes back against the car's movement, harder the
faster you go. The HUD shows the surface most of your wheels are on.

### Art style: how the ground gets its look

Everything in the game uses one cartoon "low-poly" style: the cars and the
trees, rocks and bushes all come from [Kenney](https://kenney.nl), and the
ground is painted to match. Low-poly art shows its triangles on purpose, and
uses plain colours instead of photos.

Two pieces work together to paint the ground:

- **The terrain script stores a mix in each vertex.** Every point of the
  mesh gets a colour, but it isn't used as a colour: red means "this much
  dirt", green "this much mud" and blue "this much rock". These come from
  the same surfaces that decide the car's grip, so what you see is what you
  drive on.
- **The shader turns that into flat colours.** A *shader* is a small program
  that runs on the graphics card for every pixel. It is in
  `shaders/terrain.gdshader`, and it is full of comments. It does three
  things: **flat shading** (each triangle is lit as one flat piece, so you
  see the facets), a **plain colour** for whichever surface has the biggest
  share (so the edges between grass, mud and rock are crisp), and a slightly
  different **shade for every triangle**, for that patchwork low-poly look.
  Large patches of the grass are a drier, yellower green.

To change how it looks, open `materials/terrain.tres` in the Inspector:

| Setting | What it does |
| --- | --- |
| `dirt_color`, `dry_color`, `mud_color`, `rock_color` | The colour of each surface. Dirt is the grassy ground; dry is its yellower patches. |
| `facet_variation` | How much the triangles' shades differ. 0 makes every surface one flat colour. |
| `dry_patch_size` | How big the dry patches are, in metres. |
| `mud_roughness` | 1 is matte, 0 is like a mirror. Mud is a bit shinier because it's wet. |

The sky, sun and fog are on the `WorldEnvironment` and `Sun` nodes in
`race_base.tscn`: a clear blue sky, a warm sun, light blue haze in the
distance, and a little extra colour (Adjustments > Saturation) for the
cartoon look. Mud Marsh and Rocky Ridge swap in their own: a grey, foggy day
and an orange sunset. They also use their own ground colours,
`materials/terrain_marsh.tres` and `materials/terrain_ridge.tres`.

If you empty the Terrain's `ground_material`, the terrain goes back to the
old plain colours (each surface's `color`), with smooth shading.

### Trees and rocks

The `Nature` node (`scripts/nature.gd`) scatters trees, rocks and bushes
when the game starts. It picks random spots with a `RandomNumberGenerator`
that has a fixed seed, so you get the same forest every time. A spot is
skipped if it is in the start area, close to the straight line between the
checkpoints, too close to something already placed, or on the wrong ground:
trees grow on dirt where a noise says "forest", and rocks prefer rocky
slopes and stay out of mud.

All the models come from Kenney's [Nature Kit](https://kenney.nl/assets/nature-kit)
(`assets/models/kenney_nature/`), the same artist as the cars. Each model is
only about 1 m big, so the script scales it up to a size in metres. Kenney
coloured the kit teal and orange; the script repaints it to fit our green
hills with the `palette` setting (every material in the models has a name,
like `leafsGreen` or `stone`, and gets the colour listed for that name).

- **Trees** are a mix of 12 models: tall pines, round pines and leafy
  trees. Each model is drawn by its own `MultiMeshInstance3D`, which sends
  the mesh to the graphics card once and draws it hundreds of times. That
  is much faster than 450 separate nodes. Each tree also gets a slightly
  different shade, and each trunk gets a `CylinderShape3D`, so you can crash
  into it.
- **Rocks and boulders** each get their own node with a
  `ConvexPolygonShape3D`, a "shrink-wrapped" version of the rock's shape that
  is cheap for the physics engine.
- **Bushes and grass** are only decoration: no collision, you drive through
  them.

Settings on the `Nature` node:

| Setting | What it does |
| --- | --- |
| `tree_count`, `rock_count`, `boulder_count`, `bush_count` | How many of each to place (fewer may fit). |
| `nature_seed` | Any number gives a different layout. |
| `start_clearance` | Nothing within this many metres of the start. |
| `route_clearance` | Nothing within this many metres of the line between checkpoints. |
| `tree_scenes`, `rock_scenes`, `boulder_scenes`, `bush_scenes` | Which models to use. Drag in other `.glb` files from the Nature Kit. |
| `tree_height`, `rock_size`, `boulder_size`, `bush_size` | Smallest and biggest size, in metres. |
| `palette` | The colour for each material name in the models. |

Click **Regenerate** on the Nature node after changing a setting. If you move
checkpoints, regenerate too, so the new route is kept clear (it also happens
by itself every time the game starts).

### Things to try with the terrain

- Change `map_seed` and click Regenerate to get a new map.
- Make an ice level: set Dirt's `grip` to 0.2.
- Turn mud into deep swamp: raise Mud's `drag` to 1.0.
- Make mountains: raise `hill_height` to 60 and lower `hill_frequency`.
- Grow a thick forest: set `tree_count` to 1000 and `route_clearance` to 6.
- Make it autumn: in `palette`, set `leafsGreen` to orange and `leafsDark`
  to a dark red, and set `dirt_color` in `materials/terrain.tres` to a
  yellowish brown.
- Add more of the Nature Kit: download it from
  [kenney.nl](https://kenney.nl/assets/nature-kit), copy a few `.glb` files
  from `Models/GLTF format` into `assets/models/kenney_nature/` and drag
  them into one of the `*_scenes` lists.

## How the game works

### Scenes and menus

The game is a few scenes that take turns on screen:

```
                 Point to point
main_menu.tscn ----------------> level_select.tscn --> car_select.tscn --Drive!--> scenes/levels/<level>.tscn
               \    Explore                                ^
                `-----------------------------------------'  --Drive!--> explore.tscn  (free roam)
```

The mode button you click is saved by `scripts/game_mode.gd`, and the level
you pick by `scripts/level_choice.gd`. The car-select screen shows both in
its title, and "Drive!" loads the level (or the Explore map). "Main menu" in the pause menu goes back to the start.

The car-select screen shows the real car scene inside a **SubViewport**: a
small, separate 3D world (with its own light, floor and camera) drawn inside
the 2D menu. The car's controls are turned off so it just sits there idling,
and you can hear its engine.

**Project > Project Settings > Application > Run > Main Scene** says which
one opens first (the menu). A script switches to another scene with
`get_tree().change_scene_to_file("res://scenes/car_select.tscn")`, and
`get_tree().reload_current_scene()` starts the same one over, which is all
"Restart" does.

Menus are built from **Control** nodes, Godot's 2D user-interface nodes.
Open `scenes/main_menu.tscn`: a `CenterContainer` keeps a `VBoxContainer` in
the middle of the screen, and the `VBoxContainer` stacks the title, the
buttons and the best time on top of each other. Containers do the layout
for you, so it still looks right when you resize the window.

A button sends a **signal** called `pressed` when you click it. A signal is
Godot's way of saying "this just happened". The menu script connects that
signal to a function:

```gdscript
_race_button.pressed.connect(_on_mode_pressed.bind("point_to_point"))
```

`bind(...)` adds an extra value to the call, so both mode buttons can use
the same function and it still knows which one was pressed.

### Controllers and the Input Map

The game never asks "is the W key down?". It asks about **actions**, like
`accelerate`, `steer_left` or `pause`. Open **Project > Project Settings >
Input Map** and you'll see each action with everything that triggers it: for
`accelerate` that's W, the Up arrow, and the controller's right trigger
("Joypad Axis 5 +"). `car.gd` just does

```gdscript
throttle = Input.get_axis("brake", "accelerate")
```

and gets a number from -1 to 1, whatever you pressed. A key is always all or
nothing (0 or 1), but a trigger or stick gives every value in between, so
squeezing the trigger halfway gives half power and a small push on the stick
steers a little. Each action has a **dead zone** (0.2 here): sticks never
rest at exactly zero, so anything under 20% counts as not pushed at all.

Godot calls controllers **joypads**, and it names their buttons by where
they sit on an Xbox pad: the bottom face button is "A" even on a PlayStation
pad, where it says Cross. It knows the layouts of hundreds of controllers, so
the same Input Map works for Xbox, PlayStation and most others.

The menus use Godot's built-in `ui_` actions (`ui_up`, `ui_accept`,
`ui_cancel` and so on). Buttons and lists already react to them, so a
controller can move between buttons as soon as one button has the
**focus** (that's why each screen calls `grab_focus()` on a button when it
opens). Godot doesn't put controller buttons on `ui_accept` and
`ui_cancel` by default, so this project adds A and B to them.

One gotcha: a stick sends a stream of events while you hold it over, not just
one. On the car-select screen, `event.is_action_pressed("steer_right")` is
true for every one of them, so a single push would flick through all the
cars. `Input.is_action_just_pressed_by_event("steer_right", event)` is only
true for the one event that pushed the stick past its dead zone.

### Pausing

`get_tree().paused = true` freezes the game. Every node has a
**Process > Mode** setting in the Inspector. Nodes set to "Inherit" or
"Pausable" (almost all of them) stop when the game is paused. The
`PauseMenu` is set to "Always", so it keeps running and can hear you press
Esc (or Menu / Options on a controller) again. The race timer is a normal pausable node, so it stops too.

### Checkpoints and the timer

Each checkpoint is an **Area3D**: an invisible zone that doesn't block
anything but sends a `body_entered` signal when a physics body drives into
it. `checkpoint.gd` checks that the body is a car and sends its own
`reached` signal. `race.gd` listens to all of them, counts which one is
next, and tells each one how to look (next, waiting or done).

The timer is just a number: every frame, `race.gd` adds `delta` (the
seconds since the last frame) to `elapsed`. When you finish, it compares
your time with the best one for that level and car and saves it to `user://save.cfg`
(the car you picked is saved there too). `user://` is
a folder Godot gives every game for save files, so it works the same on
every computer.

### Make your own route

Select a checkpoint under `Checkpoints` in one of the levels and drag it
somewhere else with the move tool, or type new X and Z values in the
Inspector. You don't need to get the height right: when the race starts,
each checkpoint is moved onto the ground. The order of the checkpoints in
the Scene panel is the order you drive them in, and the last one is the
finish. To add one, right-click a checkpoint and pick **Duplicate**.

If you change `map_seed` on the Terrain, move the checkpoints too, or some
may end up on top of a cliff.

### Levels

Every level is a scene in `scenes/levels/`, and they are all built on top of
`scenes/race_base.tscn`. That's called an **inherited scene**: it starts as
a copy of the base scene and only saves what's different. Open
`scenes/levels/mud_marsh.tscn` and you'll see the same nodes as in every
race. The names of the nodes that it changes have a little icon next to them;
in the Inspector, the changed settings have a ↺ "revert" arrow next to
them. Mud Marsh changes:

- **Terrain:** another `map_seed`, low hills (`hill_height`), lots of mud
  (`mud_amount`), and its own "Deep mud" surface with less grip and more drag
  than normal mud.
- **WorldEnvironment** and **Sun:** a grey sky, thicker fog and a weaker sun.
- **Nature:** fewer trees and more bushes.
- **Race:** its `level_id`, so the best times are saved for this level.
- **Checkpoints:** its own route.

If you change something in `race_base.tscn` (say, the HUD), every level gets
it, unless the level changed that same setting itself.

To make a fourth level: in the FileSystem panel, right-click
`scenes/race_base.tscn` and pick **New Inherited Scene**. Select the Terrain
and change `map_seed` and the other settings (press **Regenerate** to see
them). Drag `scenes/checkpoint.tscn` onto `Checkpoints` a few times and move
the checkpoints around. The last one is the finish. Select `Race` and give
it a new `level_id`. Save it in `scenes/levels/`, then add it to the
`LEVELS` list in `scripts/level_choice.gd` with the same id. It then shows
up on the level-select screen, with its map.

Before you add a checkpoint, check that you can drive there: steep slopes
show up grey (rock) on the map. Every route in the game was test-driven from
start to finish by a simple self-driving script with all three cars.

## How Explore mode works

Open `scenes/explore.tscn`. It looks a lot like a race level, but with a much
bigger map and no checkpoints:

```
Explore (Node3D)
├── WorldEnvironment, Sun
├── Terrain (StaticBody3D)      the 2.5 km map; scripts/explore_terrain.gd
├── PointsOfInterest (Node3D)   the 12 places to find (scenes/poi/*.tscn)
├── Nature (Node3D)             trees, rocks, bushes; scripts/explore_nature.gd
├── CarSpawner, ChaseCamera     the same as in the race
├── Exploration (Node)          the rules; scripts/exploration.gd
├── HUD (CanvasLayer)           speed, "Places found", compass, messages, map
└── PauseMenu
```

### A map ten times bigger

The race map is 256 × 256 m with a point every metre: 66 000 points, built
all at once. The Explore map is 2560 × 2560 m. Built the same way it would be
6.5 million points, which would take ages to build and be far too heavy to
draw. So it uses two tricks that nearly every open-world game uses:

- **Chunks.** The map is cut into 20 × 20 squares of 128 m, and each one is
  built on its own. They're built on a **background thread**
  (`WorkerThreadPool`), so the game keeps running smoothly while new ground
  is made.
- **Level of detail (LOD).** The chunk you're in, and the ones next to it,
  get a point every metre. Further out a point every 2 m is enough, then 4,
  8 and 16 m. From far away you can't tell, but the far chunks are only 9 × 9
  points, so the whole map can be on screen at once and you can see the
  mountains on the other side. As you drive, chunks near you are rebuilt
  with more detail, and the ones you leave get simpler again.

Where a detailed chunk meets a simpler one, their edges don't line up
exactly, so each chunk has a **skirt**: a strip of wall hanging down from its
edges that hides any crack. Only the detailed chunks around the car get
**collision** (a `HeightMapShape3D`), because that's the only place the car
can touch.

The shape of the land comes from `height_at(x, z)` in
`explore_terrain.gd`: a slow noise for big mountains and wide flat valleys,
a faster one for hills on top, a flat start, flat ground around every point
of interest (and a bowl for the pond), and walls at the edge. Because it's a
plain function of x and z, every chunk agrees with its neighbours, and the
car, the trees and the map screen can all ask it for the height anywhere.

The trees and rocks work the same way (`explore_nature.gd`), in cells of
256 m: only the 5 × 5 cells around you exist, and only the 3 × 3 closest get
collision. Each cell has its own random seed, made from its position, so if
you drive away and come back, the same trees grow in the same spots.

In the editor the Terrain is drawn at low detail, so you can see the whole
map. Settings worth trying on the `Terrain` node:

| Setting | What it does |
| --- | --- |
| `map_seed` | Any number gives a different map. Move the points of interest too! |
| `mountain_height`, `mountain_frequency` | How tall, and how wide apart, the mountains are. |
| `hill_height`, `hill_frequency` | The smaller hills on top. |
| `view_chunks`, `lod_distances` | How far you see, and where detail drops. |

### Points of interest

Each place is a small scene in `scenes/poi/`, made of Kenney models (from
the Nature, Survival and Car kits), moved, turned and scaled by hand. Open
`scenes/poi/campsite.tscn` to see one. The root node has
`scripts/point_of_interest.gd`, with an `id`, a `display_name`, a
`description`, how close you need to get (`discover_radius`), and how much
ground to flatten around it (`flat_radius`). When the game starts it gives
every big model a simple collision shape, so you bump into the tent instead
of driving through it.

`scripts/exploration.gd` checks every frame how far the car is from each
place you haven't found. Get close enough and it's yours: it plays a little
chime (made in code, like the engine sound), shows "Discovered!", and saves
the id to `user://save.cfg`, so next time you play you keep exploring where
you left off. The main menu shows how many you've found.

To find them:

- **The compass** at the top shows a **?** for every place you haven't found
  within 700 m, with its distance. It turns into a **!** when you're close.
- **The map** (press **M**) shows the whole land, where you are, the places
  you found by name, and a **?** where the others are. Set
  `show_undiscovered` on the HUD's `Map` node to off to make it harder.

To add your own place, duplicate one of the scenes in `scenes/poi/`, change
its models and give it a new `id`, then drag it under `PointsOfInterest` in
`scenes/explore.tscn` and set its X and Z. It's moved onto the ground when
the game starts.

To start over, delete `save.cfg` from the game's `user://` folder (the top of
`scripts/best_time.gd` says where that is on your computer). That also clears
your best times and locks the upgrades again.

## Making a desktop build

A "build" (Godot calls it an **export**) turns the project into a normal
program that anyone can run without installing Godot. The settings for
Windows, Linux and macOS are already set up in `export_presets.cfg`.

1. **Install the export templates (once).** These are the ready-made game
   engine programs that Godot packs your game into. In Godot, open
   **Editor > Manage Export Templates** and click **Download and Install**.
   It's a big download (about 1 GB), and the version must match your Godot.
2. Open **Project > Export**. You'll see three presets on the left:
   **Windows Desktop**, **Linux** and **macOS**.
3. Pick the one for your computer and click **Export Project…**. Untick
   **Export With Debug** for a faster game without debug tools, then click
   **Save**. The build goes into the `build/` folder, which git ignores.
4. Run it:
   - **Windows:** double-click `build/windows/Terrain.exe`. Windows may warn
     about an unknown publisher, because the game isn't signed. Click
     **More info > Run anyway**.
   - **Linux:** run `build/linux/Terrain.x86_64`.
   - **macOS:** unzip `build/macos/Terrain.zip` and open `Terrain.app`. The
     first time, macOS blocks apps from unknown developers: right-click the
     app, choose **Open**, then **Open** again.

You can export for any platform from any computer, so a Linux machine can
make the Windows build. To share the game, zip the file and send it: the
game data is packed inside the program, so it's a single file.

You can also export from the command line, without opening the editor:

```sh
godot --headless --export-release "Linux" build/linux/Terrain.x86_64
godot --headless --export-release "Windows Desktop" build/windows/Terrain.exe
godot --headless --export-release "macOS" build/macos/Terrain.zip
```

The macOS build needs the "ETC2 ASTC" texture format, for Apple Silicon
Macs. That's why it's turned on in
**Project Settings > Rendering > Textures > VRAM Compression**.

## Roadmap

1. ✅ Project setup with an empty 3D scene
2. ✅ A drivable car
3. ✅ Offroad terrain
4. ✅ Game goals, a menu and a desktop build

Since then: real ground textures, trees and rocks, three cars to pick
from, each with its own engine sound, an Explore mode on a map ten times
wider, three levels, and car upgrades you unlock by exploring.

Ideas for what's next: grass and small plants on the ground, sound for the
wheels and crashes, an arrow pointing to the next checkpoint, rivers and
lakes on the Explore map, more places to discover, or a gamepad (add buttons
to the actions in the Input Map).
