@tool
class_name Nature
extends Node3D
## Scatters trees, rocks and bushes over the terrain.
##
## How it works:
## 1. We pick random spots on the map, one at a time. A RandomNumberGenerator
##    with a fixed seed gives the same "random" spots every time, so the map
##    looks the same on every run (change nature_seed for a new layout).
## 2. Each spot has to pass some tests: not in the start area, not too close
##    to the line between the checkpoints, not too close to another tree or
##    rock, and on the right kind of ground. Trees grow on dirt in forests
##    (a noise decides where the forests are). Rocks like rocky slopes.
## 3. All models are low-poly models from Kenney's Nature Kit, the same
##    cartoon style as the cars. Each model is only about 1 m big, so we scale
##    it up to the size we want (in metres).
## 4. Trees and bushes are drawn with MultiMeshInstance3D nodes, one per
##    model: a MultiMesh draws the same mesh hundreds of times in a single go,
##    which is much faster than hundreds of separate nodes. Each tree trunk
##    gets a simple cylinder for collision. Bushes have no collision, you
##    just drive through them.
## 5. Rocks get their own node each, with a convex collision shape: a simple
##    "shrink-wrapped" version of the rock's shape.
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
@export var bush_count := 700
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

@export_group("Models")
## Tree models (.glb). A random one is picked for every tree.
@export var tree_scenes: Array[PackedScene] = []
## How tall the trees are, in metres (a random height in this range).
@export var tree_height := Vector2(7.0, 14.0)
## Small and medium rocks are picked from these.
@export var rock_scenes: Array[PackedScene] = []
## How wide the small rocks are, in metres.
@export var rock_size := Vector2(1.5, 5.0)
## Big boulders.
@export var boulder_scenes: Array[PackedScene] = []
@export var boulder_size := Vector2(5.0, 9.0)
## Bushes and grass tufts, just for decoration.
@export var bush_scenes: Array[PackedScene] = []
@export var bush_size := Vector2(0.8, 2.0)
## Kenney's Nature Kit is coloured teal and orange. We repaint it to fit our
## green hills: each material name in the models gets the colour listed here.
@export var palette := {
	"leafsGreen": Color(0.42, 0.66, 0.25),
	"leafsDark": Color(0.2, 0.46, 0.24),
	"woodBark": Color(0.52, 0.34, 0.2),
	"woodBarkDark": Color(0.42, 0.28, 0.18),
	"grass": Color(0.4, 0.64, 0.24),
	"stone": Color(0.6, 0.6, 0.62),
	"dirt": Color(0.55, 0.4, 0.27),
}

var _rng := RandomNumberGenerator.new()
var _forest_noise := FastNoiseLite.new()
# Everything placed so far, as Vector3(x, z, radius), so nothing overlaps.
# They are sorted into squares of the map (a "grid"), so to check a spot we
# only look at things in the squares next to it, not at everything.
var _placed := {}
const GRID_CELL := 8.0
# Models we already looked at, so we only do it once.
var _kinds := {}
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
	_place_rocks(boulder_scenes, boulder_count, boulder_size, true)
	_place_rocks(rock_scenes, rock_count, rock_size, false)
	_place_trees()
	_place_bushes()


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


# --- Models ------------------------------------------------------------------

# Loads a model and remembers what we need from it: its mesh, its collision
# points, and how big it is (at scale 1).
func _load_kind(scene: PackedScene) -> Dictionary:
	if scene == null:
		return {}
	if _kinds.has(scene):
		return _kinds[scene]
	var root := scene.instantiate()
	var mesh_instance := _find_mesh_instance(root)
	var result := {}
	if mesh_instance:
		var mesh := mesh_instance.mesh
		var aabb := mesh.get_aabb()
		# create_convex_shape(true, true) makes a simplified convex hull: few
		# points, cheap for the physics engine.
		var hull: ConvexPolygonShape3D = mesh.create_convex_shape(true, true)
		# Kenney's models are plain colours, one material per colour. We give
		# each material its colour from our palette, make it fully matte, and
		# let it take a tint from the MultiMesh (instance colour) so every
		# tree can be a slightly different shade.
		var materials := []
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i)
			if material is StandardMaterial3D:
				material = material.duplicate()
				if palette.has(material.resource_name):
					material.albedo_color = palette[material.resource_name]
				material.roughness = 1.0
				material.vertex_color_use_as_albedo = true
			materials.append(material)
		result = {
			"mesh": mesh,
			"materials": materials,
			"points": hull.points,
			# Where the model's bottom is, so we can put it on the ground.
			"bottom": aabb.position.y,
			"radius": maxf(aabb.size.x, aabb.size.z) * 0.5,
			"height": aabb.size.y,
		}
	root.free()
	_kinds[scene] = result
	return result


func _load_kinds(scenes: Array[PackedScene]) -> Array:
	var kinds := []
	for scene in scenes:
		var kind := _load_kind(scene)
		if not kind.is_empty():
			kinds.append(kind)
	return kinds


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null


# Makes one MultiMeshInstance3D that draws `kind` at all the transforms.
func _add_multimesh(node_name: String, kind: Dictionary, transforms: Array,
		colors: Array) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	# A MultiMesh draws the mesh with the mesh's own materials, so we give it
	# a copy of the mesh that has our matte, tintable materials.
	var mesh: ArrayMesh = kind.mesh.duplicate()
	for i in kind.materials.size():
		mesh.surface_set_material(i, kind.materials[i])
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	add_child(instance)


# A colour close to white, to tint a model a little lighter or darker.
func _random_tint(amount: float) -> Color:
	var shade := _rng.randf_range(1.0 - amount, 1.0)
	return Color(shade * _rng.randf_range(0.92, 1.0), shade, shade * _rng.randf_range(0.9, 1.0))


# --- Rocks -------------------------------------------------------------------

func _place_rocks(scenes: Array[PackedScene], count: int, size_range: Vector2,
		prefer_rock: bool) -> void:
	var kinds := _load_kinds(scenes)
	if kinds.is_empty():
		return

	var placed := 0
	var tries := 0
	while placed < count and tries < count * 40:
		tries += 1
		var kind: Dictionary = kinds[_rng.randi() % kinds.size()]
		# Scale the model so it is as wide as we want, in metres.
		var rock_scale: float = _rng.randf_range(size_range.x, size_range.y) / (kind.radius * 2.0)
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
		var sink: float = kind.bottom + kind.height * 0.15
		var origin: Vector3 = to_local(spot - up * sink * rock_scale)
		_add_rock(kind, Transform3D(rotation_basis, origin), rock_scale)
		_remember(spot, radius)
		placed += 1


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
	var kinds := _load_kinds(tree_scenes)
	if kinds.is_empty():
		return
	# One list of transforms and colours per model.
	var transforms := []
	var colors := []
	for kind in kinds:
		transforms.append([])
		colors.append([])
	var trunks := StaticBody3D.new()
	trunks.name = "TreeTrunks"
	add_child(trunks)

	var placed := 0
	var tries := 0
	while placed < tree_count and tries < tree_count * 30:
		tries += 1
		var k := _rng.randi() % kinds.size()
		var kind: Dictionary = kinds[k]
		var tree_height_m := _rng.randf_range(tree_height.x, tree_height.y)
		var tree_scale: float = tree_height_m / kind.height
		var radius: float = maxf(kind.radius * tree_scale * 0.6, 1.2)
		var spot := _find_spot(radius)
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
		# Put the bottom of the model on the ground, sunk a little so it sits
		# nicely on slopes.
		var origin: Vector3 = local + Vector3.DOWN * (kind.bottom * tree_scale + 0.3)
		transforms[k].append(Transform3D(rotation_basis, origin))
		colors[k].append(_random_tint(0.25))
		_remember(spot, radius)
		placed += 1

		# The trunk is what the car can hit.
		var shape := CylinderShape3D.new()
		shape.radius = 0.035 * tree_height_m
		shape.height = tree_height_m * 0.6
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = local + Vector3.UP * shape.height * 0.5
		trunks.add_child(collision)

	for k in kinds.size():
		_add_multimesh("Trees%d" % k, kinds[k], transforms[k], colors[k])


# --- Bushes ------------------------------------------------------------------

# Bushes and grass tufts. They are only decoration: no collision, and they
# may stand close to the route (but not on it) and near trees.
func _place_bushes() -> void:
	var kinds := _load_kinds(bush_scenes)
	if kinds.is_empty():
		return
	var transforms := []
	var colors := []
	for kind in kinds:
		transforms.append([])
		colors.append([])
	var half := terrain.size / 2.0 - edge_margin
	var placed := 0
	var tries := 0
	while placed < bush_count and tries < bush_count * 20:
		tries += 1
		var spot := terrain.to_global(Vector3(_rng.randf_range(-half, half), 0.0,
				_rng.randf_range(-half, half)))
		var flat := Vector2(spot.x, spot.z)
		if flat.distance_to(Vector2(start_position.x, start_position.z)) < start_clearance * 0.6:
			continue
		if _distance_to_route(flat) < route_clearance * 0.5:
			continue
		if terrain.get_surface_at(spot) != terrain.dirt:
			continue
		# More bushes in and around the forests.
		if _forest_noise.get_noise_2d(spot.x, spot.z) < -0.1 and _rng.randf() > 0.3:
			continue
		spot.y = terrain.get_height_at(spot)
		var k := _rng.randi() % kinds.size()
		var kind: Dictionary = kinds[k]
		var bush_scale: float = _rng.randf_range(bush_size.x, bush_size.y) / (kind.radius * 2.0)
		var rotation_basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * bush_scale)
		var origin: Vector3 = to_local(spot) + Vector3.DOWN * (kind.bottom * bush_scale + 0.1)
		transforms[k].append(Transform3D(rotation_basis, origin))
		colors[k].append(_random_tint(0.2))
		placed += 1

	for k in kinds.size():
		_add_multimesh("Bushes%d" % k, kinds[k], transforms[k], colors[k])
