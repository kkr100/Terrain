# Terrain

A learning prototype of an offroad driving game, inspired by games like
"Over the Hill". It's built with [Godot 4](https://godotengine.org/), a free
and open source game engine.

Right now the project is just an empty 3D world: a flat ground, a sun and a
camera looking at it. A drivable car, offroad terrain and game goals come later.

## How to open and run it

1. Download **Godot 4.5 or newer** (the standard version, not .NET) from
   <https://godotengine.org/download>. It's a single program, no installer needed.
2. Clone this repository, or download it as a ZIP and unpack it.
3. Start Godot. In the Project Manager, click **Import**, pick the
   `project.godot` file in this folder, then click **Import & Edit**.
4. Press **F5** (or the ▶ play button in the top right) to run the game.
   A window opens showing the brown ground under a blue sky.
   Close the window or press **F8** to stop it.

The first time you open the project Godot takes a moment to "import" it. It
creates a hidden `.godot/` folder as a cache. That folder is ignored by git,
so you never need to commit it.

## What's in the project

| File | What it is |
| --- | --- |
| `project.godot` | The project's settings: its name, window size, and which scene starts first. Godot edits this for you when you change **Project > Project Settings**. |
| `scenes/main.tscn` | The main scene, the first thing that loads when the game runs. |
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
├── Ground (MeshInstance3D)   a flat 100 × 100 m plane you can see
└── Camera3D               what the player sees when the game runs
```

Click any node and its settings show up in the **Inspector** on the right.
Try it: select `Sun` and change its rotation, or select `Ground`, open its
material and change the color. Press F5 again to see the result.

Some useful things to know:

- **Units are meters.** One unit in Godot equals one meter, which matters
  once physics and cars arrive.
- **Y is up.** The ground lies flat on the X and Z axes.
- **The ground is only visual for now.** It has no collision, so physics
  objects would fall straight through it. That gets added with the car.
- **Moving around in the editor:** hold the right mouse button and use
  W A S D to fly around the 3D view.

## Roadmap

1. ✅ Project setup with an empty 3D scene
2. A drivable car
3. Offroad terrain
4. Game goals, a menu and a desktop build
