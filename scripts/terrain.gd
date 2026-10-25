@tool
class_name Terrain
extends StaticBody3D
## Builds a hilly offroad map out of noise, with dirt, mud and rock on it.
##
## How it works, step by step:
## 1. For every point on a grid (one point per metre) we ask a noise generator
##    for a number. Noise gives smooth random values, so neighbouring points
##    get similar heights and together they form rolling hills.
## 2. We flatten a circle in the middle so the car has a calm place to start,
##    and raise the edges into steep walls so you can't drive off the map.
## 3. Each point gets a surface: steep slopes are rock, some low patches are
##    mud, and everything else is dirt.
## 4. We turn the grid into a mesh (what you see) and a HeightMapShape3D
##    (what the physics engine touches).
## 5. Each vertex remembers how much dirt, mud and rock it has (in its
##    colour: red = dirt, green = mud, blue = rock). The terrain shader
##    (shaders/terrain.gdshader) reads that and paints the ground in a
##    low-poly cartoon style, to match the cars and the trees.
##
## "@tool" at the top means this script also runs inside the editor, so you
## see the hills there too. Change a setting, then press "Regenerate".

## Press this in the Inspector to rebuild the terrain with the new settings.
@export_tool_button("Regenerate") var regenerate_button := regenerate

## Sent after the terrain was rebuilt, so things standing on it (like the
## trees and rocks in scripts/nature.gd) can move to the new ground.
signal regenerated

@export_group("Shape")
## Width and depth of the map in metres (also the number of grid cells).
@export var size := 256
## How tall the hills are, in metres.
@export var hill_height := 35.0
## Smaller numbers give wide, gentle hills. Bigger numbers give many small ones.
@export var hill_frequency := 0.007
## Change this to get a completely different map.
@export var map_seed := 7
## Radius of the flat area in the middle where the car starts, in metres.
@export var spawn_flat_radius := 10.0
## How high the walls around the edge of the map are, in metres.
@export var edge_wall_height := 30.0

@export_group("Surfaces")
## Slopes steeper than this (in degrees) are rock.
@export_range(0.0, 90.0) var rock_slope_degrees := 28.0
## Lower numbers give more mud. Between -1 (mud everywhere) and 1 (no mud).
@export_range(-1.0, 1.0) var mud_amount := 0.25
@export var dirt: SurfaceType
@export var mud: SurfaceType
@export var rock: SurfaceType

@export_group("Look")
## The material that paints the ground. materials/terrain.tres paints it in
## a flat-shaded low-poly style. Leave it empty to paint each surface its
## plain colour instead, with smooth shading.
@export var ground_material: Material

# The numbers we store per grid point to remember its surface.
enum { DIRT, MUD, ROCK }

var _heights := PackedFloat32Array()
var _surfaces := PackedByteArray()
var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	regenerate()


## Throws away the old terrain and builds a new one from the settings above.
func regenerate() -> void:
	_make_default_surfaces()
	_build_heights()
	_build_surfaces()
	_build_mesh()
	_build_collision()
	regenerated.emit()


## Which surface is under a point in the world, for example under a wheel.
func get_surface_at(world_position: Vector3) -> SurfaceType:
	var cell := _world_to_cell(world_position)
	return _surface_for_id(_surfaces[cell.y * _points() + cell.x])


## The ground height at a point in the world (handy for placing things).
func get_height_at(world_position: Vector3) -> float:
	var cell := _world_to_cell(world_position)
	return _heights[cell.y * _points() + cell.x] + global_position.y


## The direction straight out of the ground at a point in the world.
func get_normal_at(world_position: Vector3) -> Vector3:
	var cell := _world_to_cell(world_position)
	return _normal_at(cell.x, cell.y)


# --- Building the terrain ----------------------------------------------------

# Number of grid points along one side. 256 cells need 257 points.
func _points() -> int:
	return size + 1


# Turns a world position into the (x, z) grid point nearest to it.
func _world_to_cell(world_position: Vector3) -> Vector2i:
	var local := to_local(world_position)
	var half := size / 2.0
	var x := clampi(roundi(local.x + half), 0, size)
	var z := clampi(roundi(local.z + half), 0, size)
	return Vector2i(x, z)


func _make_default_surfaces() -> void:
	# If nobody set the surfaces in the Inspector, make sensible ones here.
	if dirt == null:
		dirt = _surface("Dirt", 1.0, 0.0, Color(0.58, 0.45, 0.3))
	if mud == null:
		mud = _surface("Mud", 0.45, 0.35, Color(0.3, 0.22, 0.15))
	if rock == null:
		rock = _surface("Rock", 1.4, 0.0, Color(0.5, 0.5, 0.52))


func _surface(display_name: String, grip: float, drag: float, color: Color) -> SurfaceType:
	var surface := SurfaceType.new()
	surface.display_name = display_name
	surface.grip = grip
	surface.drag = drag
	surface.color = color
	return surface


func _build_heights() -> void:
	# FastNoiseLite is Godot's built-in noise generator. "Fractal" noise adds
	# several layers (octaves) together: big hills plus smaller bumps on top.
	var noise := FastNoiseLite.new()
	noise.seed = map_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = hill_frequency
	noise.fractal_octaves = 5

	var n := _points()
	var half := size / 2.0
	_heights.resize(n * n)
	# The height at the very centre, so we can shift the map to put the
	# start area at height 0 (where the car is placed in main.tscn).
	var centre_height := _noise_height(noise, 0.0, 0.0)

	for z in n:
		for x in n:
			var px := x - half
			var pz := z - half
			var height := _noise_height(noise, px, pz) - centre_height

			# Flatten the start area. smoothstep goes from 0 to 1 between
			# the two distances, so the flat circle blends into the hills.
			var distance := Vector2(px, pz).length()
			height *= smoothstep(spawn_flat_radius, spawn_flat_radius + 25.0, distance)

			# Raise the edges into walls. edge is 0 in the middle, 1 at the border.
			var edge := maxf(absf(px), absf(pz)) / half
			height += smoothstep(0.88, 1.0, edge) * edge_wall_height

			_heights[z * n + x] = height


func _noise_height(noise: FastNoiseLite, x: float, z: float) -> float:
	# get_noise_2d returns roughly -1 to 1. Turn that into 0 to hill_height.
	return (noise.get_noise_2d(x, z) * 0.5 + 0.5) * hill_height


func _build_surfaces() -> void:
	# A second, different noise decides where the mud patches are.
	var mud_noise := FastNoiseLite.new()
	mud_noise.seed = map_seed + 1
	mud_noise.frequency = 0.03

	var n := _points()
	var half := size / 2.0
	var rock_limit := cos(deg_to_rad(rock_slope_degrees))
	_surfaces.resize(n * n)
	for z in n:
		for x in n:
			var surface := DIRT
			# The normal points straight out of the ground. On flat ground it
			# points straight up (y = 1). The steeper the slope, the smaller y.
			if _normal_at(x, z).y < rock_limit:
				surface = ROCK
			elif mud_noise.get_noise_2d(x, z) > mud_amount:
				surface = MUD
			# Keep the start area plain dirt.
			if Vector2(x - half, z - half).length() < spawn_flat_radius:
				surface = DIRT
			_surfaces[z * n + x] = surface


# The direction straight out of the ground at a grid point, worked out from
# the heights of the neighbouring points.
func _normal_at(x: int, z: int) -> Vector3:
	var n := _points()
	var left := _heights[z * n + maxi(x - 1, 0)]
	var right := _heights[z * n + mini(x + 1, size)]
	var back := _heights[maxi(z - 1, 0) * n + x]
	var front := _heights[mini(z + 1, size) * n + x]
	return Vector3(left - right, 2.0, back - front).normalized()


func _build_mesh() -> void:
	var n := _points()
	var half := size / 2.0
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var weights := _surface_weights()
	var indices := PackedInt32Array()
	vertices.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)

	# A little extra noise on the plain colours so the ground doesn't look
	# flat. (Only used when there is no ground_material.)
	var tint := FastNoiseLite.new()
	tint.seed = map_seed + 2
	tint.frequency = 0.15

	for z in n:
		for x in n:
			var i := z * n + x
			vertices[i] = Vector3(x - half, _heights[i], z - half)
			normals[i] = _normal_at(x, z)
			if ground_material:
				colors[i] = weights[i]
			else:
				var shade := 1.0 + tint.get_noise_2d(x, z) * 0.12
				colors[i] = _surface_for_id(_surfaces[i]).color * shade

	# Every grid square becomes two triangles. Godot wants the corners in
	# clockwise order when you look at the front of a triangle.
	for z in size:
		for x in size:
			var a := z * n + x
			var b := a + 1
			var c := a + n
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := ground_material
	if material == null:
		# This material paints the mesh with the colours we stored per point.
		var plain := StandardMaterial3D.new()
		plain.vertex_color_use_as_albedo = true
		plain.roughness = 1.0
		material = plain
	mesh.surface_set_material(0, material)

	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance)
	_mesh_instance.mesh = mesh


# How much dirt (red), mud (green) and rock (blue) each grid point has.
# Each point is 100% one surface, but we average it with its neighbours so the
# textures fade into each other over a metre or two instead of making hard,
# blocky edges.
func _surface_weights() -> PackedColorArray:
	var n := _points()
	var pure := [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]
	var weights := PackedColorArray()
	weights.resize(n * n)
	for z in n:
		for x in n:
			var sum := Color(0, 0, 0, 0)
			var count := 0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var sx := clampi(x + dx, 0, size)
					var sz := clampi(z + dz, 0, size)
					sum += pure[_surfaces[sz * n + sx]]
					count += 1
			weights[z * n + x] = sum / count
	return weights


func _build_collision() -> void:
	# HeightMapShape3D is a collision shape made for terrain: a grid of
	# heights, one metre apart, centred on the node. That's exactly our grid.
	var shape := HeightMapShape3D.new()
	shape.map_width = _points()
	shape.map_depth = _points()
	shape.map_data = _heights
	if _collision == null:
		_collision = CollisionShape3D.new()
		add_child(_collision)
	_collision.shape = shape


func _surface_for_id(id: int) -> SurfaceType:
	match id:
		MUD:
			return mud
		ROCK:
			return rock
	return dirt
