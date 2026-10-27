@tool
class_name ExploreTerrain
extends StaticBody3D
## The big map for Explore mode: 2.5 km across, ten times wider than the race
## map (so a hundred times more ground).
##
## The race map (scripts/terrain.gd) builds the whole map at once, one point
## per metre. Doing that here would mean 6.5 million points: far too slow to
## build and too heavy to draw. So this map uses two tricks that almost every
## open-world game uses:
##
## 1. Chunks. The map is cut into squares ("chunks") of 128 x 128 m. Only the
##    chunks around the camera are built. When you drive on, new chunks are
##    built in front of you and old ones far behind you are thrown away.
## 2. Level of detail (LOD). Chunks close to you get a point every metre.
##    Further away a point every 2 m is enough, then 4 m, 8 m and 16 m. You
##    can't see the difference from far away, but it's far less work.
##
## Building a chunk happens on a background thread (WorkerThreadPool), so the
## game keeps running smoothly while new ground is made.
##
## Only the chunks right around you get collision (a HeightMapShape3D), since
## that's the only place the car can touch.
##
## The height of every point comes from height_at(), which mixes some noise
## layers: big mountains, smaller hills, a flat start area, flat ground at
## every point of interest, and walls at the edge. Since it is a function of
## x and z only, every chunk agrees with its neighbours where they meet.
##
## In the editor ("@tool") the whole map is drawn at low detail, so you can
## see its shape. Press "Regenerate" after changing a setting.

@export_tool_button("Regenerate") var regenerate_button := regenerate

@export_group("Shape")
## Width and depth of the map in metres. Must be a multiple of chunk_size.
@export var size := 2560
## Change this to get a completely different map.
@export var map_seed := 21
## How tall the mountains are, in metres.
@export var mountain_height := 160.0
## Smaller numbers give fewer, wider mountains.
@export var mountain_frequency := 0.0007
## How tall the smaller hills on top are, in metres.
@export var hill_height := 22.0
@export var hill_frequency := 0.007
## Radius of the flat area in the middle where the car starts, in metres.
@export var spawn_flat_radius := 14.0
## How high the walls around the edge of the map are, in metres.
@export var edge_wall_height := 70.0
## The points of interest (its children). The ground is made flat around
## each of them, so buildings don't hang over a slope.
@export var points_of_interest_root: Node3D

@export_group("Surfaces")
## Slopes steeper than this (in degrees) are rock.
@export_range(0.0, 90.0) var rock_slope_degrees := 33.0
## Lower numbers give more mud. Between -1 (mud everywhere) and 1 (no mud).
@export_range(-1.0, 1.0) var mud_amount := 0.4
@export var dirt: SurfaceType
@export var mud: SurfaceType
@export var rock: SurfaceType
@export var ground_material: Material

@export_group("Chunks")
## Size of one chunk in metres.
@export var chunk_size := 128
## The node to build the map around, usually the camera.
@export var follow: Node3D
## Chunks this many chunks away from the one you're in are still drawn.
## 20 is the whole map (it's 20 chunks wide). Far chunks are so simple
## that drawing all of them is cheap, and you can see mountains far away.
@export var view_chunks := 20
## Detail by distance. Chunks up to lod_distances[0] chunks away get a point
## every 1 m, up to lod_distances[1] every 2 m, then 4 m, 8 m, and anything
## further every 16 m. The 1 m chunks also get collision.
@export var lod_distances := PackedInt32Array([1, 2, 4, 7])
## How many chunks may be built at the same time in the background.
@export var max_jobs := 6
## In the editor the whole map is built with a point every this many metres.
@export var editor_step := 16

# The numbers we use for each surface (same as in terrain.gd).
enum { DIRT, MUD, ROCK }
const SURFACE_COLORS := [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]

var _mountain_noise := FastNoiseLite.new()
var _hill_noise := FastNoiseLite.new()
var _mud_noise := FastNoiseLite.new()
var _centre_height := 0.0
var _rock_limit := 0.0
# Flat places, one Vector4 per point of interest: (x, z, radius, height).
var _sites := PackedVector4Array()
# How deep a bowl to dig at each site (for ponds), in metres.
var _site_dips := PackedFloat32Array()

# The chunks that exist now: Vector2i(chunk x, chunk z) -> {"step", "mesh", "collision"}
var _chunks := {}
# Chunks being built in the background: Vector3i(x, z, step) -> task id
var _jobs := {}
# Finished background work, waiting to be added to the scene.
var _results := {}
var _mutex := Mutex.new()
# The chunk the camera was in last frame, and whether some chunks still
# need to be started, so we don't check all 400 chunks every single frame.
var _last_centre := Vector2i(-1, -1)
var _needs_update := true


func _ready() -> void:
	regenerate()


func _exit_tree() -> void:
	_wait_for_jobs()


# Never leave a background job running on a node that's being deleted.
func _wait_for_jobs() -> void:
	for task_id in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(task_id)
	_jobs.clear()


## Throws away all chunks and builds the map again from the settings.
func regenerate() -> void:
	_wait_for_jobs()
	for chunk in _chunks.values():
		_free_chunk(chunk)
	_chunks.clear()
	_results.clear()
	_needs_update = true
	_setup()
	if Engine.is_editor_hint():
		# In the editor: everything, at low detail.
		@warning_ignore("integer_division")
		var count := size / chunk_size
		for cz in count:
			for cx in count:
				_add_chunk(_build_chunk(Vector3i(cx, cz, editor_step)))
	else:
		# In the game: build the chunks right around the start now, so the car
		# has ground under it from the very first frame. The rest is built in
		# the background by _process().
		var centre := _chunk_of(follow.global_position if follow else global_position)
		for cz in range(centre.y - 1, centre.y + 2):
			for cx in range(centre.x - 1, centre.x + 2):
				if _in_map(Vector2i(cx, cz)):
					_add_chunk(_build_chunk(Vector3i(cx, cz, 1)))


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or follow == null:
		return
	_collect_finished_jobs()
	var centre := _chunk_of(follow.global_position)
	if centre != _last_centre or _needs_update:
		_last_centre = centre
		_needs_update = not _update_chunks(centre)


# --- The shape of the land ---------------------------------------------------

func _setup() -> void:
	if dirt == null:
		dirt = _surface("Dirt", 1.0, 0.0)
	if mud == null:
		mud = _surface("Mud", 0.45, 0.35)
	if rock == null:
		rock = _surface("Rock", 1.4, 0.0)
	_rock_limit = cos(deg_to_rad(rock_slope_degrees))

	_mountain_noise.seed = map_seed
	_mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mountain_noise.frequency = mountain_frequency
	_mountain_noise.fractal_octaves = 4
	_hill_noise.seed = map_seed + 1
	_hill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hill_noise.frequency = hill_frequency
	_hill_noise.fractal_octaves = 4
	_mud_noise.seed = map_seed + 2
	_mud_noise.frequency = 0.01
	_mud_noise.fractal_octaves = 2

	_sites.clear()
	_site_dips.clear()
	_centre_height = _land_height(0.0, 0.0)
	if points_of_interest_root:
		for point in points_of_interest_root.get_children():
			if point is PointOfInterest:
				var local := to_local(point.global_position)
				var height := _shaped_height(local.x, local.z)
				_sites.append(Vector4(local.x, local.z, point.flat_radius, height))
				_site_dips.append(point.basin_depth)


## The height of the ground at (x, z), in this node's own space.
func height_at(x: float, z: float) -> float:
	var height := _shaped_height(x, z)
	# Make the ground flat around every point of interest. "blend" is 0 inside
	# the flat circle and grows to 1 over the next 30 m, so the flat spot fades
	# smoothly into the hills.
	for i in _sites.size():
		var site := _sites[i]
		var distance := Vector2(x - site.x, z - site.y).length()
		if distance > site.z + 30.0:
			continue
		var flat := site.w
		if _site_dips[i] > 0.0:
			# A round bowl, deepest in the middle (for ponds).
			var inside := clampf(distance / (site.z * 0.75), 0.0, 1.0)
			flat -= _site_dips[i] * (1.0 - inside * inside)
		height = lerpf(flat, height, smoothstep(site.z, site.z + 30.0, distance))
	return height


# The noise hills, with the start area flattened and the walls at the edge.
func _shaped_height(x: float, z: float) -> float:
	var height := _land_height(x, z) - _centre_height
	height *= smoothstep(spawn_flat_radius, spawn_flat_radius + 40.0, Vector2(x, z).length())
	var edge := maxf(absf(x), absf(z)) / (size / 2.0)
	height += smoothstep(0.94, 1.0, edge) * edge_wall_height
	return height


# Just the noise: big mountains plus smaller hills.
func _land_height(x: float, z: float) -> float:
	# Noise gives about -0.6 to 0.6. smoothstep turns everything below -0.25
	# into 0 (wide, flat valleys) and everything above 0.5 into 1 (the
	# mountain tops), with smooth slopes in between.
	var mountains := smoothstep(-0.25, 0.5, _mountain_noise.get_noise_2d(x, z))
	var hills := _hill_noise.get_noise_2d(x, z) * 0.5 + 0.5
	return mountains * mountain_height + hills * hill_height


## Which surface (DIRT, MUD or ROCK) is at (x, z). Works out the slope from
## the heights one metre to the side, so it's the same at every detail level.
func surface_id_at(x: float, z: float) -> int:
	var height := height_at(x, z)
	return _surface_id(x, z, height, height_at(x + 1.0, z), height_at(x, z + 1.0))


func _surface_id(x: float, z: float, height: float, height_x: float, height_z: float) -> int:
	if Vector2(x, z).length() < spawn_flat_radius:
		return DIRT
	var up := Vector3(height - height_x, 1.0, height - height_z).normalized().y
	if up < _rock_limit:
		return ROCK
	if _mud_noise.get_noise_2d(x, z) > mud_amount:
		return MUD
	return DIRT


## Which surface is under a point in the world, for example under a wheel.
## The car asks this (see _apply_ground() in car.gd).
func get_surface_at(world_position: Vector3) -> SurfaceType:
	var local := to_local(world_position)
	match surface_id_at(local.x, local.z):
		MUD:
			return mud
		ROCK:
			return rock
	return dirt


## The ground height at a point in the world.
func get_height_at(world_position: Vector3) -> float:
	var local := to_local(world_position)
	return height_at(local.x, local.z) + global_position.y


## The direction straight out of the ground at a point in the world.
func get_normal_at(world_position: Vector3) -> Vector3:
	var local := to_local(world_position)
	return normal_at(local.x, local.z)


## The direction straight out of the ground at (x, z), in this node's space.
func normal_at(x: float, z: float) -> Vector3:
	var height := height_at(x, z)
	return Vector3(height - height_at(x + 1.0, z), 1.0, height - height_at(x, z + 1.0)).normalized()


## A small picture of the whole map seen from above, for the map screen.
## Each pixel is coloured by its surface and shaded by its slope. This is
## slow-ish, so call it from a background thread.
func make_map_image(pixels: int) -> Image:
	var image := Image.create(pixels, pixels, false, Image.FORMAT_RGB8)
	var metres := float(size) / pixels
	var half := size / 2.0
	var light := Vector3(-1.0, 1.5, -1.0).normalized()
	for j in pixels:
		for i in pixels:
			var x := -half + (i + 0.5) * metres
			var z := -half + (j + 0.5) * metres
			var height := height_at(x, z)
			var height_x := height_at(x + metres, z)
			var height_z := height_at(x, z + metres)
			var normal := Vector3((height - height_x) / metres, 1.0, (height - height_z) / metres).normalized()
			var color: Color
			match _surface_id(x, z, height, height_at(x + 1.0, z), height_at(x, z + 1.0)):
				MUD:
					color = mud.color
				ROCK:
					color = rock.color
				_:
					# Higher ground gets a bit lighter and yellower.
					color = dirt.color.lerp(Color(0.78, 0.8, 0.45), clampf(height / mountain_height, 0.0, 0.6))
			var shade := clampf(normal.dot(light) * 1.3, 0.45, 1.25)
			image.set_pixel(i, j, color * shade)
	return image


# The material for the ground's meshes.
func _chunk_material() -> Material:
	return ground_material


# The colour a surface gets in the mesh. The shader reads it as "how much of
# each surface": pure red is dirt, green is mud, blue is rock.
func _surface_color(surface_id: int) -> Color:
	return SURFACE_COLORS[surface_id]


func _surface(display_name: String, grip: float, drag: float) -> SurfaceType:
	var surface := SurfaceType.new()
	surface.display_name = display_name
	surface.grip = grip
	surface.drag = drag
	return surface


# --- Chunks ------------------------------------------------------------------

func _chunk_of(world_position: Vector3) -> Vector2i:
	var local := to_local(world_position)
	var half := size / 2.0
	return Vector2i(floori((local.x + half) / chunk_size), floori((local.z + half) / chunk_size))


func _in_map(chunk: Vector2i) -> bool:
	@warning_ignore("integer_division")
	var count := size / chunk_size
	return chunk.x >= 0 and chunk.y >= 0 and chunk.x < count and chunk.y < count


# How many metres between points for a chunk this many chunks away.
func _step_for(distance: int) -> int:
	for i in lod_distances.size():
		if distance <= lod_distances[i]:
			return 1 << i  # 1, 2, 4, 8 (the "<<" shift doubles the 1 i times)
	return 1 << lod_distances.size()


# Works out which chunks we need now, starts building any that are missing
# (closest first), and removes the ones that are too far away. Returns false
# if it couldn't start them all yet (too many jobs running already).
func _update_chunks(centre: Vector2i) -> bool:
	for chunk: Vector2i in _chunks.keys():
		var distance := maxi(absi(chunk.x - centre.x), absi(chunk.y - centre.y))
		if distance > view_chunks + 1:
			_free_chunk(_chunks[chunk])
			_chunks.erase(chunk)

	for distance in view_chunks + 1:
		var step := _step_for(distance)
		for chunk in _ring(centre, distance):
			if not _in_map(chunk):
				continue
			var existing: Dictionary = _chunks.get(chunk, {})
			if existing.get("step", 0) == step:
				continue
			var key := Vector3i(chunk.x, chunk.y, step)
			if _jobs.has(key):
				continue
			if _jobs.size() >= max_jobs:
				return false
			_jobs[key] = WorkerThreadPool.add_task(_build_chunk_job.bind(key))
	return true


# All chunks that are exactly "distance" chunks away from centre (a square ring).
func _ring(centre: Vector2i, distance: int) -> Array[Vector2i]:
	var ring: Array[Vector2i] = []
	if distance == 0:
		ring.append(centre)
		return ring
	for i in range(-distance, distance + 1):
		ring.append(centre + Vector2i(i, -distance))
		ring.append(centre + Vector2i(i, distance))
	for i in range(-distance + 1, distance):
		ring.append(centre + Vector2i(-distance, i))
		ring.append(centre + Vector2i(distance, i))
	return ring


# This runs on a background thread. It may only do maths and make new data:
# it must not touch the scene tree.
func _build_chunk_job(key: Vector3i) -> void:
	var data := _build_chunk(key)
	_mutex.lock()
	_results[key] = data
	_mutex.unlock()


func _collect_finished_jobs() -> void:
	var centre := _chunk_of(follow.global_position)
	for key: Vector3i in _jobs.keys():
		if not WorkerThreadPool.is_task_completed(_jobs[key]):
			continue
		WorkerThreadPool.wait_for_task_completion(_jobs[key])
		_jobs.erase(key)
		_mutex.lock()
		var data: Dictionary = _results.get(key, {})
		_results.erase(key)
		_mutex.unlock()
		# While it was being built, we may have driven on. Only use it if
		# that chunk still wants this level of detail.
		var chunk := Vector2i(key.x, key.y)
		var distance := maxi(absi(chunk.x - centre.x), absi(chunk.y - centre.y))
		if not data.is_empty() and distance <= view_chunks and _step_for(distance) == key.z:
			_add_chunk(data)
		else:
			_needs_update = true


# Works out all the numbers for one chunk: the points, their colours and
# the triangles between them.
func _build_chunk(key: Vector3i) -> Dictionary:
	var step := key.z
	@warning_ignore("integer_division")
	var cells := chunk_size / step
	var n := cells + 1
	var half := size / 2.0
	# The chunk's corner and centre, in this node's space.
	var x0 := -half + key.x * chunk_size
	var z0 := -half + key.y * chunk_size
	var centre := Vector3(x0 + chunk_size / 2.0, 0.0, z0 + chunk_size / 2.0)

	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = height_at(x0 + i * step, z0 + j * step)

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(n * n)
	colors.resize(n * n)
	for j in n:
		for i in n:
			var x := x0 + i * step
			var z := z0 + j * step
			var index := j * n + i
			var height := heights[index]
			# The heights 1 m further along x and z, for the slope. With 1 m
			# detail we already have them, except along the far edges.
			var height_x := heights[index + 1] if step == 1 and i < n - 1 else height_at(x + 1.0, z)
			var height_z := heights[index + n] if step == 1 and j < n - 1 else height_at(x, z + 1.0)
			# Vertices are relative to the chunk's centre (where its node is).
			vertices[index] = Vector3(x, height, z) - centre
			colors[index] = _surface_color(_surface_id(x, z, height, height_x, height_z))

	var indices := PackedInt32Array()
	for j in cells:
		for i in cells:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	_add_skirt(vertices, colors, indices, n, step)

	return {
		"key": key,
		"centre": centre,
		"heights": heights,
		"vertices": vertices,
		"colors": colors,
		"indices": indices,
	}


# Where a detailed chunk meets a less detailed one, their edges don't line up
# exactly and you could see thin cracks through the ground. A "skirt" hides
# them: a strip of wall hanging down from every edge of the chunk.
func _add_skirt(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array, n: int, step: int) -> void:
	var edge := PackedInt32Array()
	for i in n:
		edge.append(i)  # Back edge.
	for j in range(1, n):
		edge.append(j * n + n - 1)  # Right edge.
	for i in range(n - 2, -1, -1):
		edge.append((n - 1) * n + i)  # Front edge.
	for j in range(n - 2, 0, -1):
		edge.append(j * n)  # Left edge.
	edge.append(0)
	var depth := Vector3.DOWN * (2.0 + step * 1.5)
	for k in edge.size() - 1:
		var top_a := edge[k]
		var top_b := edge[k + 1]
		var bottom_a := vertices.size()
		vertices.append(vertices[top_a] + depth)
		colors.append(colors[top_a])
		vertices.append(vertices[top_b] + depth)
		colors.append(colors[top_b])
		var bottom_b := bottom_a + 1
		# Both sides, so it hides the crack from whichever side you look.
		indices.append_array([top_a, top_b, bottom_a, top_b, bottom_b, bottom_a])
		indices.append_array([top_a, bottom_a, top_b, top_b, bottom_a, bottom_b])


# Turns the numbers from _build_chunk() into a mesh in the scene, plus
# collision if it's a detailed chunk. This must run on the main thread.
func _add_chunk(data: Dictionary) -> void:
	var key: Vector3i = data.key
	var chunk := Vector2i(key.x, key.y)
	if _chunks.has(chunk):
		_free_chunk(_chunks[chunk])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_COLOR] = data.colors
	arrays[Mesh.ARRAY_INDEX] = data.indices
	# The shader works out its own (flat) normals, but Godot still wants some.
	var normals := PackedVector3Array()
	normals.resize(data.vertices.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _chunk_material())

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = data.centre
	add_child(mesh_instance)
	# Tell the shader how big this chunk's triangles are, for its shading.
	mesh_instance.set_instance_shader_parameter("facet_size", float(key.z))
	var result := {"step": key.z, "mesh": mesh_instance, "collision": null}

	if key.z == 1:
		# HeightMapShape3D: a grid of heights 1 m apart, centred on its node.
		var n := chunk_size + 1
		var shape := HeightMapShape3D.new()
		shape.map_width = n
		shape.map_depth = n
		shape.map_data = data.heights
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = data.centre
		add_child(collision)
		result.collision = collision
	_chunks[chunk] = result


func _free_chunk(chunk: Dictionary) -> void:
	chunk.mesh.queue_free()
	if chunk.collision:
		chunk.collision.queue_free()
