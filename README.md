# Terrain

A learning prototype of an offroad driving game, inspired by games like
"Over the Hill". It's built with [Godot 4](https://godotengine.org/), a free
and open source game engine.

Right now you can drive a small 4x4 around a hilly offroad map with dirt, mud
and rock, each with its own grip. Game goals come later.

## How to open and run it

1. Download **Godot 4.5 or newer** (the standard version, not .NET) from
   <https://godotengine.org/download>. It's a single program, no installer needed.
2. Clone this repository, or download it as a ZIP and unpack it.
3. Start Godot. In the Project Manager, click **Import**, pick the
   `project.godot` file in this folder, then click **Import & Edit**.
4. Press **F5** (or the ▶ play button in the top right) to run the game.
   A window opens with a red car in a valley between hills. Close the window or press
   **F8** to stop it.

## Controls

| Key | What it does |
| --- | --- |
| **W** or **↑** | Drive forward |
| **S** or **↓** | Brake. Once you've stopped, hold it to reverse. |
| **A D** or **← →** | Steer |
| **Space** | Handbrake |
| **R** | Flip the car back onto its wheels |

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
| `scenes/main.tscn` | The main scene, the first thing that loads when the game runs. It holds the map, the car, the camera and the speed display. |
| `scenes/car.tscn` | The car on its own: body, wheels and suspension. |
| `scripts/car.gd` | Reads the keyboard and tells the car to drive, brake and steer. |
| `scripts/chase_camera.gd` | Makes the camera follow the car from behind. |
| `scripts/hud.gd` | Shows the speed, the ground you're on, and the controls. |
| `scripts/terrain.gd` | Builds the hills, paints the dirt, mud and rock, and tells the car which surface is under a wheel. |
| `scripts/surface_type.gd` | Describes one kind of ground: its name, grip, drag and colour. |
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
├── Car                    the car, an instance of scenes/car.tscn
├── ChaseCamera (Camera3D) what the player sees; it follows the car
└── HUD (CanvasLayer)      2D text drawn on top of the 3D world
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

## How the car works

Open `scenes/car.tscn` to see the car on its own:

```
Car (VehicleBody3D)        the physics body; scripts/car.gd is attached here
├── CollisionShape3D       a box, the shape that bumps into things
├── Body, Cabin, Headlights  boxes you see (just looks, no physics)
└── WheelFrontLeft … WheelRearRight (VehicleWheel3D)
    └── Tire               a cylinder you see spinning
```

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
| `wheel_radius` | Size of the wheel. Keep it the same as the Tire mesh. |
| `wheel_rest_length` | How long the spring is when nothing presses on it. |
| `suspension_travel` | How far the spring can squash. |
| `suspension_stiffness` | Spring strength. Low = soft and bouncy, high = stiff. |
| `damping_compression` / `damping_relaxation` | Shock absorbers: they stop the car bouncing forever. |
| `wheel_friction_slip` | Grip. Low numbers make the car slide, which is fun offroad. |
| `use_as_traction` / `use_as_steering` | Whether the engine drives this wheel / whether it steers. All four drive, only the front two steer. |

**Forward is +Z.** A `VehicleBody3D` drives towards its blue Z arrow. That's
why the headlights are on the +Z end of the car.

**The script** `scripts/car.gd` runs `_physics_process` 60 times a second. It
reads the keys with `Input.get_axis(...)` and sets `engine_force`, `brake` and
`steering`. The numbers at the top marked `@export` show up in the Inspector
when you select the car, so you can tune the top speed or engine power without
editing code.

**The camera** in `scripts/chase_camera.gd` works out a spot behind and above
the car, then each frame moves only part of the way there. That lag is what
makes it feel smooth. Try changing `follow_speed` and `distance` on the
`ChaseCamera` node.

### Things to try

- Make the car slide more: lower `wheel_friction_slip` on all four wheels.
- Make it a rear-wheel-drive car: untick `use_as_traction` on the front wheels.
- Make it a monster truck: raise `wheel_radius` on the wheels and the Tire
  meshes, and raise `wheel_rest_length`.
- Raise `max_engine_force` on the Car node and launch off a hilltop.

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
4. **Mesh and collision.** The grid becomes an `ArrayMesh` (what you see,
   coloured per surface) and a `HeightMapShape3D` (what the wheels touch).
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

### Things to try with the terrain

- Change `map_seed` and click Regenerate to get a new map.
- Make an ice level: set Dirt's `grip` to 0.2.
- Turn mud into deep swamp: raise Mud's `drag` to 1.0.
- Make mountains: raise `hill_height` to 60 and lower `hill_frequency`.

## Roadmap

1. ✅ Project setup with an empty 3D scene
2. ✅ A drivable car
3. ✅ Offroad terrain
4. Game goals, a menu and a desktop build
