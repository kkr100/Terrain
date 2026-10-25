@tool
class_name Nature
extends Node3D
## Scatters trees and rocks over the terrain.
##
## How it works:
## 1. We pick random spots on the map, one at a time. A RandomNumberGenerator
##    with a fixed seed gives the same "random" spots every time, so the map
##    looks the same on every run (change nature_seed for a new layout).
## 2. Each spot has to pass some tests: not in the start area, not too close
##    to the line between the checkpoints, not too close to another tree or
##    rock, and on the right kind of ground. Trees grow on dirt in forests
##    (a noise decides where the forests are). Rocks like rocky slopes.
## 3. Trees are drawn with one MultiMeshInstance3D: it draws the same mesh
##    hundreds of times in a single go, which is much faster than hundreds of
##    separate nodes. Each tree trunk gets a simple cylinder for collision.
## 4. Rocks are real scanned rock models (from Poly Haven). They get their own
##    MeshInstance3D each, so Godot can use a simpler version (a "LOD", level
##    of detail) for rocks that are far away. Each rock gets a convex
##    collision shape, a simple "shrink-wrapped" version of its shape.
##
## Like the terrain, this script runs in the editor too ("@tool"). Press
## "Regenerate" in the Inspector after changing a setting.

@export_tool_button("Regenerate") var regenerate_button := regenerate

## The terrain to put things on.
@export var terrain: Terrain
## The node whose children are the checkpoints. We keep the route between
## them clear, so there's always a way through.
@export var checkpoints_root: Node3D
## Where the car starts. Nothing is placed near it.
@export var start_position := Vector3.ZERO

@export_group("Amounts")
@export var tree_count := 450
@export var rock_count := 120
@export var boulder_count := 18
## Change this to get a different layout of trees and rocks.
@export var nature_seed := 3

@export_group("Keep clear")
## Nothing is placed closer than this to the start, in metres.
@export var start_clearance := 22.0
## Nothing is placed closer than this to the straight line between
## checkpoints, in metres.
@export var route_clearance := 9.0
## Stay this far away from the edge of the map (where the walls are).
@export var edge_margin := 20.0

@export_group("Look")
## The bark texture for the tree trunks.
@export var bark_texture: Texture2D
@export var bark_normal: Texture2D
## The colour of the pine needles.
@export var needle_color := Color(0.16, 0.27, 0.12)
## Scanned rock models (.gltf). Small and medium rocks are picked from these.
@export var rock_scenes: Array[PackedScene] = []
## Big boulders.
@export var boulder_scenes: Array[PackedScene] = []

var _rng := RandomNumberGenerator.new()
var _forest_noise := FastNoiseLite.new()
# Everything placed so far, as Vector3(x, z, radius), so nothing overlaps.
# They are sorted into squares of the map (a "grid"), so to check a spot we
# only look at things in the squares next to it, not at everything.
var _placed := {}
const GRID_CELL := 8.0
# Rock models we already looked at, so we only do it once.
var _rock_kinds := {}
var _route := PackedVector2Array()


func _ready() -> void:
	if terrain and not terrain.regenerated.is_connected(regenerate):
		terrain.regenerated.connect(regenerate)
	regenerate()


## Removes all trees and rocks and places new ones.
func regenerate() -> void:
	if terrain == null:
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()

	_rng.seed = nature_seed
	_forest_noise.seed = nature_seed
	_forest_noise.frequency = 0.012
	_placed.clear()
	_build_route()

	# Boulders first, since they are the biggest and hardest to fit.
	_place_rocks(boulder_scenes, boulder_count, 3.0, 6.0, true)
	_place_rocks(rock_scenes, rock_count, 6.0, 20.0, false)
	_place_trees()


# --- Where things may go -----------------------------------------------------

func _build_route() -> void:
	# The route is the line from the start through every checkpoint in order.
	_route = PackedVector2Array([Vector2(start_position.x, start_position.z)])
	if checkpoints_root:
		for checkpoint in checkpoints_root.get_children():
			if checkpoint is Node3D:
				_route.append(Vector2(checkpoint.position.x, checkpoint.position.z))


# The distance from a point to the closest part of the route.
func _distance_to_route(point: Vector2) -> float:
	var best := INF
	for i in range(1, _route.size()):
		var closest := Geometry2D.get_closest_point_to_segment(point, _route[i - 1], _route[i])
		best = minf(best, point.distance_to(closest))
	return best


# A random spot on the map that is clear of the start, the route and
# everything placed so far. Returns Vector3.INF if we didn't find one.
func _find_spot(radius: float) -> Vector3:
	var half := terrain.size / 2.0 - edge_margin
	var x := _rng.randf_range(-half, half)
	var z := _rng.randf_range(-half, half)
	var flat := Vector2(x, z)
	if flat.distance_to(Vector2(start_position.x, start_position.z)) < start_clearance + radius:
		return Vector3.INF
	if _distance_to_route(flat) < route_clearance + radius:
		return Vector3.INF
	var cell := _grid_cell(flat)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for other: Vector3 in _placed.get(cell + Vector2i(dx, dz), []):
				if flat.distance_to(Vector2(other.x, other.y)) < radius + other.z:
					return Vector3.INF
	var world := terrain.to_global(Vector3(x, 0.0, z))
	world.y = terrain.get_height_at(world)
	return world


func _grid_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / GRID_CELL), floori(point.y / GRID_CELL))


# Remembers that something with this radius now stands at this spot.
func _remember(spot: Vector3, radius: float) -> void:
	var cell := _grid_cell(Vector2(spot.x, spot.z))
	if not _placed.has(cell):
		_placed[cell] = []
	_placed[cell].append(Vector3(spot.x, spot.z, radius))


# --- Rocks -------------------------------------------------------------------

func _place_rocks(scenes: Array[PackedScene], count: int, min_scale: float,
		max_scale: float, prefer_rock: bool) -> void:
	var kinds := []
	for scene in scenes:
		var kind := _load_rock(scene)
		if not kind.is_empty():
			kinds.append(kind)
	if kinds.is_empty():
		return

	var placed := 0
	var tries := 0
	while placed < count and tries < count * 40:
		tries += 1
		var kind: Dictionary = kinds[_rng.randi() % kinds.size()]
		var rock_scale := _rng.randf_range(min_scale, max_scale)
		var radius: float = kind.radius * rock_scale
		var spot := _find_spot(radius)
		if spot == Vector3.INF:
			continue
		var surface := terrain.get_surface_at(spot)
		# Rocks don't sit in mud. Big boulders mostly want rocky slopes.
		if surface == terrain.mud:
			continue
		if prefer_rock and surface != terrain.rock and _rng.randf() < 0.75:
			continue
		if not prefer_rock and surface != terrain.rock and _rng.randf() < 0.5:
			continue

		# Tilt the rock to follow the slope a bit, spin it randomly, and sink
		# it into the ground so it doesn't look like it is floating.
		var up := Vector3.UP.lerp(terrain.get_normal_at(spot), 0.6).normalized()
		var rotation_basis := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, _rng.randf() * TAU)
		var origin: Vector3 = to_local(spot - up * kind.height * rock_scale * 0.2)
		_add_rock(kind, Transform3D(rotation_basis, origin), rock_scale)
		_remember(spot, radius)
		placed += 1


# Loads a rock model and remembers what we need from it: its mesh, its
# collision points, and how big it is.
func _load_rock(scene: PackedScene) -> Dictionary:
	if scene == null:
		return {}
	if _rock_kinds.has(scene):
		return _rock_kinds[scene]
	var root := scene.instantiate()
	var mesh_instance := _find_mesh_instance(root)
	var result := {}
	if mesh_instance:
		var mesh := mesh_instance.mesh
		var aabb := mesh.get_aabb()
		# create_convex_shape(true, true) makes a simplified convex hull: few
		# points, cheap for the physics engine.
		var hull: ConvexPolygonShape3D = mesh.create_convex_shape(true, true)
		# The scanned rocks come with a "roughness" texture that makes them a
		# bit shiny once they are scaled up to boulder size. We make a copy of
		# each material that is evenly rough (matte) instead.
		var materials := []
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i)
			if material is StandardMaterial3D:
				material = material.duplicate()
				material.roughness_texture = null
				material.roughness = 0.9
			materials.append(material)
		result = {
			"mesh": mesh,
			"materials": materials,
			"points": hull.points,
			"radius": maxf(aabb.size.x, aabb.size.z) * 0.5,
			"height": aabb.size.y,
		}
	root.free()
	_rock_kinds[scene] = result
	return result


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null


func _add_rock(kind: Dictionary, xform: Transform3D, rock_scale: float) -> void:
	# The physics body is not scaled (physics doesn't like scaled shapes), so
	# we make the collision points bigger instead.
	var body := StaticBody3D.new()
	body.transform = xform
	add_child(body)

	var points := PackedVector3Array()
	for point: Vector3 in kind.points:
		points.append(point * rock_scale)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = kind.mesh
	for i in kind.materials.size():
		mesh_instance.set_surface_override_material(i, kind.materials[i])
	mesh_instance.scale = Vector3.ONE * rock_scale
	body.add_child(mesh_instance)


# --- Trees -------------------------------------------------------------------

func _place_trees() -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var trunks := StaticBody3D.new()
	trunks.name = "TreeTrunks"
	add_child(trunks)

	var tries := 0
	while transforms.size() < tree_count and tries < tree_count * 30:
		tries += 1
		var tree_scale := _rng.randf_range(0.7, 1.4)
		var spot := _find_spot(1.6 * tree_scale)
		if spot == Vector3.INF:
			continue
		# Trees grow in forests: only where the forest noise is high enough,
		# with a few lonely trees in between.
		var forest := _forest_noise.get_noise_2d(spot.x, spot.z)
		if forest < 0.05 and _rng.randf() > 0.06:
			continue
		if terrain.get_surface_at(spot) != terrain.dirt:
			continue
		if terrain.get_normal_at(spot).y < 0.9:
			continue

		var local := to_local(spot)
		var rotation_basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * tree_scale)
		# Sink the trunk a little so it sits nicely on slopes.
		transforms.append(Transform3D(rotation_basis, local + Vector3.DOWN * 0.4))
		# A slightly different green for every tree.
		var shade := _rng.randf_range(0.7, 1.0)
		colors.append(Color(shade * _rng.randf_range(0.85, 1.0), shade, shade * _rng.randf_range(0.8, 1.0)))
		_remember(spot, 1.6 * tree_scale)

		# The trunk is what the car can hit.
		var shape := CylinderShape3D.new()
		shape.radius = 0.35 * tree_scale
		shape.height = 6.0 * tree_scale
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = local + Vector3.UP * shape.height * 0.5
		trunks.add_child(collision)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _make_pine_mesh()
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	var trees := MultiMeshInstance3D.new()
	trees.name = "Trees"
	trees.multimesh = multimesh
	add_child(trees)


## Builds a simple pine tree out of a trunk and a few stacked cones.
## The tree is about 11 m tall at scale 1.
func _make_pine_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()

	# The trunk: a cylinder that gets thinner towards the top.
	var trunk := SurfaceTool.new()
	trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cone(trunk, 0.0, 9.0, 0.32, 0.06, 8, 0.0, Color.WHITE, Color.WHITE, 3.0)
	trunk.generate_normals()
	trunk.generate_tangents()
	trunk.commit(mesh)
	var bark := StandardMaterial3D.new()
	bark.albedo_texture = bark_texture
	bark.normal_enabled = bark_normal != null
	bark.normal_texture = bark_normal
	bark.roughness = 0.95
	mesh.surface_set_material(0, bark)

	# The needles: layers of cones, each a bit smaller than the one below.
	# The bottom of each layer is darker, like it is in its own shadow.
	var needles := SurfaceTool.new()
	needles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers := 5
	for i in layers:
		var t := float(i) / layers
		var bottom := 2.0 + t * 7.0
		var height := 3.4 - t * 1.4
		var radius := 2.4 - t * 1.7
		_add_cone(needles, bottom, bottom + height, radius, 0.0, 11, 0.6,
				Color(0.5, 0.5, 0.5), Color(1, 1, 1), 1.0)
	needles.generate_normals()
	needles.commit(mesh)
	var needle_material := StandardMaterial3D.new()
	needle_material.albedo_color = needle_color
	# Multiplies the colour with the vertex colour (the dark layer bottoms)
	# and with each tree's own colour from the MultiMesh.
	needle_material.vertex_color_use_as_albedo = true
	needle_material.roughness = 0.9
	needle_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(1, needle_material)
	return mesh


## Adds a cone (or a cylinder, if top_radius > 0) to a SurfaceTool.
## `jitter` pushes the bottom ring in and out, so needle layers look ragged.
func _add_cone(st: SurfaceTool, y0: float, y1: float, bottom_radius: float,
		top_radius: float, sides: int, jitter: float, bottom_color: Color,
		top_color: Color, v_repeat: float) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var r0 := bottom_radius + (jitter if i % 2 == 0 else -jitter * 0.5)
		var r1 := bottom_radius + (jitter if (i + 1) % 2 == 0 else -jitter * 0.5)
		if (i + 1) == sides:
			r1 = bottom_radius + jitter  # Close the ring where it started.
		var b0 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r1, y0, sin(a1) * r1)
		var t0 := Vector3(cos(a0) * top_radius, y1, sin(a0) * top_radius)
		var t1 := Vector3(cos(a1) * top_radius, y1, sin(a1) * top_radius)
		var u0 := float(i) / sides
		var u1 := float(i + 1) / sides
		# Two triangles per side, corners in clockwise order seen from outside.
		_vertex(st, b0, Vector2(u0, v_repeat), bottom_color)
		_vertex(st, b1, Vector2(u1, v_repeat), bottom_color)
		_vertex(st, t0, Vector2(u0, 0.0), top_color)
		_vertex(st, b1, Vector2(u1, v_repeat), bottom_color)
		_vertex(st, t1, Vector2(u1, 0.0), top_color)
		_vertex(st, t0, Vector2(u0, 0.0), top_color)


func _vertex(st: SurfaceTool, point: Vector3, uv: Vector2, color: Color) -> void:
	st.set_color(color)
	st.set_uv(uv)
	st.add_vertex(point)
