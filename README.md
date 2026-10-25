# Terrain

A learning prototype of an offroad driving game, inspired by games like
"Over the Hill". It's built with [Godot 4](https://godotengine.org/), a free
and open source game engine.

Pick one of three cars, a light rally hatch, a trail SUV or a heavy pickup,
and drive it across a hilly offroad map with dirt, mud and rock, each with
its own grip. Your goal: drive through 8 checkpoints and the finish line, in
order, as fast as you can. The game remembers your best time with each car.

## How to open and run it

1. Download **Godot 4.5 or newer** (the standard version, not .NET) from
   <https://godotengine.org/download>. It's a single program, no installer needed.
2. Clone this repository, or download it as a ZIP and unpack it.
3. Start Godot. In the Project Manager, click **Import**, pick the
   `project.godot` file in this folder, then click **Import & Edit**.
4. Press **F5** (or the ▶ play button in the top right) to run the game.
   The main menu opens. Click **Start** (or press Enter), pick a car, then
   click **Drive!** to begin a race.
   Close the window or press **F8** to stop it.

Want to skip the menu while you're working on the map or the car? Open
`scenes/main.tscn` and press **F6** (or the "Run current scene" button). That
runs just the scene you have open.

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

| Key | What it does |
| --- | --- |
| **W** or **↑** | Drive forward |
| **S** or **↓** | Brake. Once you've stopped, hold it to reverse. |
| **A D** or **← →** | Steer |
| **Space** | Handbrake |
| **R** | Flip the car back onto its wheels |
| **Esc** or **P** | Pause (and unpause) |

The map is surrounded by steep rock walls. If the car ever falls through the
world, it's put back at the start.
The keys live in **Project > Project Settings > Input Map**, so you can change
them there without touching any code.

The first time you open the project Godot takes a moment to "import" it. It
creates a hidden `.godot/` folder as a cache. That folder is ignored by git,
so you never need to commit it.

## What's in the project

| File | What it is |
| --- | --- |
| `project.godot` | The project's settings: its name, window size, and which scene starts first. Godot edits this for you when you change **Project > Project Settings**. |
| `export_presets.cfg` | The settings for making a Windows, Linux or macOS build. See "Making a desktop build" below. |
| `scenes/main_menu.tscn` | The main menu, the first thing that loads when the game runs. |
| `scenes/main.tscn` | The race: the map, the car, the checkpoints, the camera and the HUD. |
| `scenes/checkpoint.tscn` | One checkpoint (a beam of light and a ring). `main.tscn` uses it nine times. |
| `scenes/pause_menu.tscn` | The menu that shows when you press Esc. |
| `scenes/car_select.tscn` | The car-select screen, with a 3D preview of each car. |
| `scenes/cars/rally.tscn`, `suv.tscn`, `pickup.tscn` | The three cars: model, wheels, suspension and engine sound. |
| `scripts/car.gd` | Used by all three cars. Reads the keyboard and tells the car to drive, brake and steer. |
| `scripts/engine_sound.gd` | Makes each car's engine noise in code, following the RPM. |
| `scripts/car_choice.gd` | The list of cars (names, descriptions, stat bars) and which one you picked. |
| `scripts/car_spawner.gd` | Puts the car you picked into the race. |
| `scripts/car_select.gd` | Makes the car-select screen work. |
| `scripts/chase_camera.gd` | Makes the camera follow the car from behind. |
| `scripts/hud.gd` | Shows the speed, the race info, the countdown and the finish screen. |
| `scripts/race.gd` | The game rules: countdown, timer, which checkpoint is next, the finish. |
| `scripts/checkpoint.gd` | Notices when the car drives through a checkpoint, and changes its colour. |
| `scripts/best_time.gd` | Saves and loads your best time with each car. |
| `scripts/main_menu.gd` | Makes the Start and Quit buttons work. |
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

Open `scenes/main.tscn` and look at the **Scene** panel on the left. It shows
this tree:

```
Main (Node3D)              the root; every other node hangs under it
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
└── EngineSound (AudioStreamPlayer)  the engine noise; scripts/engine_sound.gd
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

There are no sound files: `engine_sound.gd` makes the sound while the game
runs, with an `AudioStreamGenerator`. A sound is a long list of numbers
between -1 and 1 that the speaker follows, 22050 of them each second here.
Each time a cylinder fires the script plays a short "bang" that fades out.
Faster RPM means the bangs come closer together, so the note gets higher.
That's why a 4-cylinder buzzes and a V8 rumbles. `car.gd` works out the RPM
and gear from the speed, like an automatic gearbox, and the HUD shows both.

Select a car's `EngineSound` node and try `cylinders`, `sharpness`, `rumble`
(an uneven, lumpy V8 sound) and `brightness_hz` (lower sounds more muffled).

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

**Which car is in the race?** `main.tscn` doesn't contain a car. Instead the
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

## How the terrain works

Select the `Terrain` node in `scenes/main.tscn`. Its script,
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
`main.tscn`: a clear blue sky, a warm sun, light blue haze in the distance,
and a little extra colour (Adjustments > Saturation) for the cartoon look.

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

The game is four scenes that take turns on screen:

```
main_menu.tscn  --Start-->  car_select.tscn  --Drive!-->  main.tscn  --Main menu-->  main_menu.tscn
```

The car-select screen shows the real car scene inside a **SubViewport**: a
small, separate 3D world (with its own light, floor and camera) drawn inside
the 2D menu. The car's controls are turned off so it just sits there idling,
and you can hear its engine.

**Project > Project Settings > Application > Run > Main Scene** says which
one opens first (the menu). A script switches to another scene with
`get_tree().change_scene_to_file("res://scenes/main.tscn")`, and
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
_start_button.pressed.connect(_on_start_pressed)
```

### Pausing

`get_tree().paused = true` freezes the game. Every node has a
**Process > Mode** setting in the Inspector. Nodes set to "Inherit" or
"Pausable" (almost all of them) stop when the game is paused. The
`PauseMenu` is set to "Always", so it keeps running and can hear you press
Esc again. The race timer is a normal pausable node, so it stops too.

### Checkpoints and the timer

Each checkpoint is an **Area3D**: an invisible zone that doesn't block
anything but sends a `body_entered` signal when a physics body drives into
it. `checkpoint.gd` checks that the body is a car and sends its own
`reached` signal. `race.gd` listens to all of them, counts which one is
next, and tells each one how to look (next, waiting or done).

The timer is just a number: every frame, `race.gd` adds `delta` (the
seconds since the last frame) to `elapsed`. When you finish, it compares
your time with the best one for that car and saves it to `user://save.cfg`
(the car you picked is saved there too). `user://` is
a folder Godot gives every game for save files, so it works the same on
every computer.

### Make your own route

Select a checkpoint under `Checkpoints` in `scenes/main.tscn` and drag it
somewhere else with the move tool, or type new X and Z values in the
Inspector. You don't need to get the height right: when the race starts,
each checkpoint is moved onto the ground. The order of the checkpoints in
the Scene panel is the order you drive them in, and the last one is the
finish. To add one, right-click a checkpoint and pick **Duplicate**.

If you change `map_seed` on the Terrain, move the checkpoints too, or some
may end up on top of a cliff.

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

Since then: real ground textures, trees and rocks, and three cars to pick
from, each with its own engine sound.

Ideas for what's next: grass and small plants on the ground, sound for the wheels and crashes, a mini-map or
an arrow pointing to the next checkpoint, more maps with different seeds,
or a gamepad (add buttons to the actions in the Input Map).
