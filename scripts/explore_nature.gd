class_name ExploreNature
extends Node3D
## Trees, rocks and bushes for the big Explore map.
##
## It works like scripts/nature.gd on the race map, but the Explore map is far
## too big to fill with trees all at once (it would need around 40 000 of
## them). So, like the terrain, the scenery is split into square "cells" of
## 256 x 256 m, and only the cells around the camera exist:
##
## - Each cell gets its own random number generator, seeded with the cell's
##   position. So a cell always gets exactly the same trees, even if it is
##   thrown away and built again later.
## - Working out where everything goes happens on a background thread. Then
##   the main thread puts it into the scene, with one MultiMeshInstance3D per
##   model per cell (a MultiMesh draws hundreds of copies in one go).
## - Only the cells right around the car get collision (tree trunks and
##   rocks), since that's the only place the car can hit something.

## The map to put things on.
@export var terrain: ExploreTerrain
## The node to build the scenery around, usually the camera.
@export var follow: Node3D
## Things are not placed near these points of interest (its children).
@export var points_of_interest_root: Node3D

@export_group("Cells")
## Size of one cell, in metres.
@export var cell_size := 256.0
## Cells this many cells away are still built (2 means a 5 x 5 square).
@export var view_cells := 2
## Cells this many cells away get collision.
@export var collision_cells := 1
## Bushes are small, so we stop drawing them this far away, in metres.
@export var bush_view_distance := 260.0

@export_group("Amounts per cell")
@export var tree_count := 380
@export var rock_count := 70
@export var boulder_count := 12
@export var bush_count := 450
## Change this to get a different layout of trees and rocks.
@export var nature_seed := 5

@export_group("Keep clear")
## Nothing is placed closer than this to the start, in metres.
@export var start_clearance := 30.0
## Stay this far away from the edge of the map (where the walls are).
@export var edge_margin := 60.0

@export_group("Models")
@export var tree_scenes: Array[PackedScene] = []
@export var tree_height := Vector2(7.0, 15.0)
@export var rock_scenes: Array[PackedScene] = []
@export var rock_size := Vector2(1.5, 5.0)
@export var boulder_scenes: Array[PackedScene] = []
@export var boulder_size := Vector2(5.0, 10.0)
@export var bush_scenes: Array[PackedScene] = []
@export var bush_size := Vector2(0.8, 2.0)

# Each kind of model, loaded once (see nature_models.gd).
var _trees := []
var _rocks := []
var _boulders := []
var _bushes := []
var _forest_noise := FastNoiseLite.new()
# Places to keep clear: Vector3(x, z, radius).
var _clear_spots := PackedVector3Array()

# The cells that exist now: Vector2i -> {"nodes": [...], "collision": body or null, "data": {...}}
var _cells := {}
var _jobs := {}  # Vector2i -> task id
var _results := {}
var _mutex := Mutex.new()


func _ready() -> void:
	_trees = _load_kinds(tree_scenes)
	_rocks = _load_kinds(rock_scenes)
	_boulders = _load_kinds(boulder_scenes)
	_bushes = _load_kinds(bush_scenes)
	_forest_noise.seed = nature_seed
	_forest_noise.frequency = 0.004
	_forest_noise.fractal_octaves = 3

	_clear_spots.append(Vector3(0.0, 0.0, start_clearance))
	if points_of_interest_root:
		for point in points_of_interest_root.get_children():
			if point is PointOfInterest:
				var local := terrain.to_local(point.global_position)
				_clear_spots.append(Vector3(local.x, local.z, point.flat_radius + 6.0))

	# Build the cell we start in right away, so there's no empty first frame.
	var centre := _cell_of(follow.global_position)
	_add_cell(centre, _build_cell(centre))


func _exit_tree() -> void:
	for task_id in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(task_id)
	_jobs.clear()


func _process(_delta: float) -> void:
	var centre := _cell_of(follow.global_position)
	_collect_finished_jobs()

	for cz in range(centre.y - view_cells, centre.y + view_cells + 1):
		for cx in range(centre.x - view_cells, centre.x + view_cells + 1):
			var cell := Vector2i(cx, cz)
			if not _in_map(cell) or _cells.has(cell) or _jobs.has(cell):
				continue
			# Fewer jobs at once than the terrain, so the ground comes first.
			if _jobs.size() < 2:
				_jobs[cell] = WorkerThreadPool.add_task(_build_cell_job.bind(cell))

	for cell: Vector2i in _cells.keys():
		var distance := maxi(absi(cell.x - centre.x), absi(cell.y - centre.y))
		if distance > view_cells + 1:
			_free_cell(_cells[cell])
			_cells.erase(cell)
		else:
			_set_collision(cell, distance <= collision_cells)


func _cell_of(world_position: Vector3) -> Vector2i:
	var local := terrain.to_local(world_position)
	var half := terrain.size / 2.0
	return Vector2i(floori((local.x + half) / cell_size), floori((local.z + half) / cell_size))


func _in_map(cell: Vector2i) -> bool:
	var count := ceili(terrain.size / cell_size)
	return cell.x >= 0 and cell.y >= 0 and cell.x < count and cell.y < count


func _load_kinds(scenes: Array[PackedScene]) -> Array:
	var kinds := []
	for scene in scenes:
		var kind := NatureModels.load_kind(scene, NatureModels.PALETTE)
		if not kind.is_empty():
			kinds.append(kind)
	return kinds


# --- Working out where things go (background thread) -------------------------

func _build_cell_job(cell: Vector2i) -> void:
	var data := _build_cell(cell)
	_mutex.lock()
	_results[cell] = data
	_mutex.unlock()


func _collect_finished_jobs() -> void:
	for cell: Vector2i in _jobs.keys():
		if not WorkerThreadPool.is_task_completed(_jobs[cell]):
			continue
		WorkerThreadPool.wait_for_task_completion(_jobs[cell])
		_jobs.erase(cell)
		_mutex.lock()
		var data: Dictionary = _results.get(cell, {})
		_results.erase(cell)
		_mutex.unlock()
		if not data.is_empty():
			_add_cell(cell, data)


# Picks the spots for everything in one cell. Returns, for each model, a list
# of transforms and colours, plus what needs collision.
func _build_cell(cell: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	# hash() turns the numbers into one big number: a seed only this cell has.
	rng.seed = hash([nature_seed, cell.x, cell.y])
	var half := terrain.size / 2.0
	var corner := Vector2(-half + cell.x * cell_size, -half + cell.y * cell_size)
	var data := {
		"trees": _empty_lists(_trees.size()),
		"rocks": _empty_lists(_rocks.size()),
		"boulders": _empty_lists(_boulders.size()),
		"bushes": _empty_lists(_bushes.size()),
		# Tree trunks: Vector4(x, y, z, height).
		"trunks": PackedVector4Array(),
		# Rocks: [kind, transform without scale, scale].
		"rock_bodies": [],
	}
	var placed := {}
	_place_rocks(rng, corner, data, placed, _boulders, "boulders", boulder_count, boulder_size, true)
	_place_rocks(rng, corner, data, placed, _rocks, "rocks", rock_count, rock_size, false)
	_place_trees(rng, corner, data, placed)
	_place_bushes(rng, corner, data)
	return data


func _empty_lists(count: int) -> Array:
	var lists := []
	for i in count:
		lists.append({"transforms": [], "colors": []})
	return lists


# A random spot in the cell, or Vector3.INF if it's in a place to keep clear
# or too close to something placed already.
func _find_spot(rng: RandomNumberGenerator, corner: Vector2, placed: Dictionary, radius: float) -> Vector3:
	var x := corner.x + rng.randf() * cell_size
	var z := corner.y + rng.randf() * cell_size
	var limit := terrain.size / 2.0 - edge_margin
	if absf(x) > limit or absf(z) > limit:
		return Vector3.INF
	for spot in _clear_spots:
		if Vector2(x - spot.x, z - spot.y).length() < spot.z + radius:
			return Vector3.INF
	# "placed" sorts things into 8 m squares, so we only check the nearby ones.
	var grid := Vector2i(floori(x / 8.0), floori(z / 8.0))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for other: Vector3 in placed.get(grid + Vector2i(dx, dz), []):
				if Vector2(x - other.x, z - other.y).length() < radius + other.z:
					return Vector3.INF
	return Vector3(x, terrain.height_at(x, z), z)


func _remember(placed: Dictionary, spot: Vector3, radius: float) -> void:
	var grid := Vector2i(floori(spot.x / 8.0), floori(spot.z / 8.0))
	if not placed.has(grid):
		placed[grid] = []
	placed[grid].append(Vector3(spot.x, spot.z, radius))


func _place_rocks(rng: RandomNumberGenerator, corner: Vector2, data: Dictionary, placed: Dictionary,
		kinds: Array, list_name: String, count: int, size_range: Vector2, prefer_rock: bool) -> void:
	if kinds.is_empty():
		return
	var done := 0
	var tries := 0
	while done < count and tries < count * 30:
		tries += 1
		var k := rng.randi() % kinds.size()
		var kind: Dictionary = kinds[k]
		var rock_scale: float = rng.randf_range(size_range.x, size_range.y) / (kind.radius * 2.0)
		var radius: float = kind.radius * rock_scale
		var spot := _find_spot(rng, corner, placed, radius)
		if spot == Vector3.INF:
			continue
		var surface := terrain.surface_id_at(spot.x, spot.z)
		if surface == ExploreTerrain.MUD:
			continue
		var chance := 0.25 if prefer_rock else 0.5
		if surface != ExploreTerrain.ROCK and rng.randf() > chance:
			continue
		# Tilt the rock to follow the slope a bit, spin it, and sink it into
		# the ground so it doesn't float.
		# (This runs on a background thread, so we use the terrain's own maths
		# functions, which don't touch the scene tree.)
		var normal := terrain.normal_at(spot.x, spot.z)
		var up := Vector3.UP.lerp(normal, 0.6).normalized()
		var rotation_basis := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, rng.randf() * TAU)
		var sink: float = kind.bottom + kind.height * 0.15
		var origin := spot - up * sink * rock_scale
		data[list_name][k].transforms.append(Transform3D(rotation_basis.scaled(Vector3.ONE * rock_scale), origin))
		data[list_name][k].colors.append(NatureModels.random_tint(rng, 0.15))
		data.rock_bodies.append([kind, Transform3D(rotation_basis, origin), rock_scale])
		_remember(placed, spot, radius)
		done += 1


func _place_trees(rng: RandomNumberGenerator, corner: Vector2, data: Dictionary, placed: Dictionary) -> void:
	if _trees.is_empty():
		return
	var done := 0
	var tries := 0
	while done < tree_count and tries < tree_count * 12:
		tries += 1
		var k := rng.randi() % _trees.size()
		var kind: Dictionary = _trees[k]
		var height := rng.randf_range(tree_height.x, tree_height.y)
		var tree_scale: float = height / kind.height
		var radius: float = maxf(kind.radius * tree_scale * 0.6, 1.2)
		var spot := _find_spot(rng, corner, placed, radius)
		if spot == Vector3.INF:
			continue
		# Trees grow in forests (where the forest noise is high), with a few
		# lonely trees in between.
		if _forest_noise.get_noise_2d(spot.x, spot.z) < 0.08 and rng.randf() > 0.04:
			continue
		if terrain.surface_id_at(spot.x, spot.z) != ExploreTerrain.DIRT:
			continue
		var rotation_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * tree_scale)
		var origin: Vector3 = spot + Vector3.DOWN * (kind.bottom * tree_scale + 0.3)
		data.trees[k].transforms.append(Transform3D(rotation_basis, origin))
		data.trees[k].colors.append(NatureModels.random_tint(rng, 0.25))
		data.trunks.append(Vector4(spot.x, spot.y, spot.z, height))
		_remember(placed, spot, radius)
		done += 1


func _place_bushes(rng: RandomNumberGenerator, corner: Vector2, data: Dictionary) -> void:
	if _bushes.is_empty():
		return
	var done := 0
	var tries := 0
	while done < bush_count and tries < bush_count * 10:
		tries += 1
		var spot := _find_spot(rng, corner, {}, 0.5)
		if spot == Vector3.INF:
			continue
		if _forest_noise.get_noise_2d(spot.x, spot.z) < -0.15 and rng.randf() > 0.25:
			continue
		if terrain.surface_id_at(spot.x, spot.z) != ExploreTerrain.DIRT:
			continue
		var k := rng.randi() % _bushes.size()
		var kind: Dictionary = _bushes[k]
		var bush_scale: float = rng.randf_range(bush_size.x, bush_size.y) / (kind.radius * 2.0)
		var rotation_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * bush_scale)
		var origin: Vector3 = spot + Vector3.DOWN * (kind.bottom * bush_scale + 0.1)
		data.bushes[k].transforms.append(Transform3D(rotation_basis, origin))
		data.bushes[k].colors.append(NatureModels.random_tint(rng, 0.2))
		done += 1


# --- Putting it in the scene (main thread) -----------------------------------

func _add_cell(cell: Vector2i, data: Dictionary) -> void:
	var nodes := []
	nodes.append_array(_add_multimeshes(_trees, data.trees, true, 0.0))
	nodes.append_array(_add_multimeshes(_boulders, data.boulders, true, 0.0))
	nodes.append_array(_add_multimeshes(_rocks, data.rocks, true, 0.0))
	nodes.append_array(_add_multimeshes(_bushes, data.bushes, false, bush_view_distance))
	_cells[cell] = {"nodes": nodes, "collision": null, "data": data}


func _add_multimeshes(kinds: Array, lists: Array, shadows: bool, view_distance: float) -> Array:
	var nodes := []
	for k in kinds.size():
		var transforms: Array = lists[k].transforms
		if transforms.is_empty():
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = kinds[k].mesh
		multimesh.instance_count = transforms.size()
		for i in transforms.size():
			multimesh.set_instance_transform(i, transforms[i])
			multimesh.set_instance_color(i, lists[k].colors[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		if not shadows:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if view_distance > 0.0:
			# visibility_range_end hides it when the camera is further away.
			instance.visibility_range_end = view_distance
		# The transforms are in the terrain's space, so we put the MultiMesh
		# exactly where the terrain is.
		add_child(instance)
		instance.global_transform = terrain.global_transform
		nodes.append(instance)
	return nodes


# Adds or removes the tree trunks and rocks the car can hit, for one cell.
func _set_collision(cell: Vector2i, wanted: bool) -> void:
	var info: Dictionary = _cells[cell]
	if wanted == (info.collision != null):
		return
	if not wanted:
		info.collision.queue_free()
		info.collision = null
		return
	var body := StaticBody3D.new()
	add_child(body)
	body.global_transform = terrain.global_transform
	var data: Dictionary = info.data
	for trunk in data.trunks:
		var shape := CylinderShape3D.new()
		shape.radius = 0.035 * trunk.w
		shape.height = trunk.w * 0.6
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(trunk.x, trunk.y + shape.height * 0.5, trunk.z)
		body.add_child(collision)
	for rock: Array in data.rock_bodies:
		# Physics doesn't like scaled shapes, so we scale the points instead.
		var points := PackedVector3Array()
		for point: Vector3 in rock[0].points:
			points.append(point * rock[2])
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = rock[1]
		body.add_child(collision)
	info.collision = body


func _free_cell(info: Dictionary) -> void:
	for node in info.nodes:
		node.queue_free()
	if info.collision:
		info.collision.queue_free()
