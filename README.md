# Terrain

A learning prototype of an offroad driving game, inspired by games like
"Over the Hill". It's built with [Godot 4](https://godotengine.org/), a free
and open source game engine.

Right now you can drive a small 4x4 around a flat test map with a ramp and
some bumps. Offroad terrain and game goals come later.

## How to open and run it

1. Download **Godot 4.5 or newer** (the standard version, not .NET) from
   <https://godotengine.org/download>. It's a single program, no installer needed.
2. Clone this repository, or download it as a ZIP and unpack it.
3. Start Godot. In the Project Manager, click **Import**, pick the
   `project.godot` file in this folder, then click **Import & Edit**.
4. Press **F5** (or the ▶ play button in the top right) to run the game.
   A window opens with a red car on brown ground. Close the window or press
   **F8** to stop it.

## Controls

| Key | What it does |
| --- | --- |
| **W** or **↑** | Drive forward |
| **S** or **↓** | Brake. Once you've stopped, hold it to reverse. |
| **A D** or **← →** | Steer |
| **Space** | Handbrake |
| **R** | Flip the car back onto its wheels |

If you drive off the edge of the map, the car is put back at the start.
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
| `scripts/hud.gd` | Shows the speed and the controls on screen. |
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
├── Ground (StaticBody3D)   a flat 200 × 200 m floor that doesn't move
│   ├── Mesh               what you see
│   └── CollisionShape3D   what the physics engine touches
├── TestProps              a ramp and three bumps to try the suspension on
├── Car                    the car, an instance of scenes/car.tscn
├── ChaseCamera (Camera3D) what the player sees; it follows the car
└── HUD (CanvasLayer)      2D text drawn on top of the 3D world
```

Click any node and its settings show up in the **Inspector** on the right.
Try it: select `Sun` and change its rotation, or select `Ground`, open its
material and change the color. Press F5 again to see the result.

Some useful things to know:

- **Units are meters.** One unit in Godot equals one meter, which matters
  once physics and cars arrive.
- **Y is up.** The ground lies flat on the X and Z axes.
- **Seeing and touching are separate.** A `MeshInstance3D` is only a picture.
  Physics only knows about `CollisionShape3D` nodes. That's why the ground has
  both. If you add a new obstacle, give it both or the car drives through it.
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
- Raise `max_engine_force` on the Car node and jump off the ramp.

## Roadmap

1. ✅ Project setup with an empty 3D scene
2. ✅ A drivable car
3. Offroad terrain
4. Game goals, a menu and a desktop build
