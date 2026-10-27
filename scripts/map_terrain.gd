@tool
class_name MapTerrain
extends ExploreTerrain
## The ground in Experimental mode. It is the Explore terrain (same chunks,
## detail levels and collision, see explore_terrain.gd), but the shape of the
## land comes from a map poster instead of noise.
##
## The map (an ExploreMapData) has a picture, terrain.png, with one pixel
## every 2.5 m. Each pixel stores a height and what the poster shows there:
## open ground, sand, forest, water or a trail. height_at() reads the four
## pixels around a spot and blends them (that's called "bilinear
## interpolation"), then adds some small bumps so it's fun to drive on.
##
## The water is one big flat sheet at height 0. Lakes and rivers are simply
## the places where the ground is lower than that.
##
## With no map, this is exactly the Explore terrain. Experimental mode uses
## that for its copy of the Explore map.

## The map to build. ExperimentalMap sets it when the game starts. To see a
## map in the editor, drag a .tres from assets/maps/ here and press Regenerate.
@export var map: ExploreMapData:
	set(value):
		map = value
		_read_map()

## The ground's material on a map (map_terrain.gdshader). Without a map,
## "Ground Material" is used, like on the Explore map.
@export var map_ground_material: Material

## The extra surfaces on a map. DIRT (used for grass), MUD and ROCK are
## ExploreTerrain's.
enum { SAND = 3, MEADOW, SNOW, TRACK, WATER }

## The kinds of ground in terrain.png's blue channel.
enum Ground { OPEN, SAND, FOREST, WATER, TRAIL }

## Spots lower than this are in the water.
const WATER_LEVEL := 0.0

# terrain.png's pixels: 3 bytes (red, green, blue) for each.
var _pixels := PackedByteArray()
var _pixels_wide := 0
# How many metres one step of red * 256 + green is.
var _metres_per_step := 0.0
var _start_height := 0.0
var _bump_noise := FastNoiseLite.new()
var _patch_noise := FastNoiseLite.new()
# The SurfaceType for each surface number (DIRT, MUD, ... WATER).
var _surfaces: Array[SurfaceType] = []
var _water: MeshInstance3D


func _read_map() -> void:
	_pixels = PackedByteArray()
	if map == null or map.terrain_image == null:
		return
	var image := map.terrain_image
	if image.get_format() != Image.FORMAT_RGB8:
		image = image.duplicate()
		image.convert(Image.FORMAT_RGB8)
	_pixels = image.get_data()
	_pixels_wide = image.get_width()
	_metres_per_step = (map.highest - map.lowest) / 65535.0
	_start_height = map_height_at(map.start.x, map.start.y)


func _setup() -> void:
	if map == null:
		super()
		return
	dirt = map.grass
	mud = map.mud
	rock = map.rock
	mud_amount = map.mud_amount
	_surfaces = [map.grass, map.mud, map.rock, map.sand, map.meadow, map.snow, map.track, map.lakebed]
	_bump_noise.seed = map_seed + 3
	_bump_noise.frequency = 0.05
	_bump_noise.fractal_octaves = 2
	_patch_noise.seed = map_seed + 4
	_patch_noise.frequency = 0.006
	_patch_noise.fractal_octaves = 3
	# This sets up the rest, like the flat ground at the points of interest.
	super()
	_add_water()


# --- Reading the map ---------------------------------------------------------

## The height from the map picture alone (no bumps, no flat start), at (x, z)
## in this node's space.
func map_height_at(x: float, z: float) -> float:
	if _pixels.is_empty():
		return 0.0
	# Which pixel we're in, as a fraction: pixel 0's middle is 1.25 m in from
	# the edge of the map.
	var last := _pixels_wide - 1.001
	var px := clampf((x + size / 2.0) / size * _pixels_wide - 0.5, 0.0, last)
	var pz := clampf((z + size / 2.0) / size * _pixels_wide - 0.5, 0.0, last)
	var ix := int(px)
	var iz := int(pz)
	var fx := px - ix
	var fz := pz - iz
	var top := lerpf(_pixel_height(ix, iz), _pixel_height(ix + 1, iz), fx)
	var bottom := lerpf(_pixel_height(ix, iz + 1), _pixel_height(ix + 1, iz + 1), fx)
	return lerpf(top, bottom, fz)


func _pixel_height(ix: int, iz: int) -> float:
	var k := (iz * _pixels_wide + ix) * 3
	return (_pixels[k] * 256 + _pixels[k + 1]) * _metres_per_step + map.lowest


## What the poster shows at (x, z): one of the Ground values.
func ground_at(x: float, z: float) -> int:
	var ix := clampi(floori((x + size / 2.0) / size * _pixels_wide), 0, _pixels_wide - 1)
	var iz := clampi(floori((z + size / 2.0) / size * _pixels_wide), 0, _pixels_wide - 1)
	return _pixels[(iz * _pixels_wide + ix) * 3 + 2]


# --- The shape of the land ---------------------------------------------------

func _shaped_height(x: float, z: float) -> float:
	if map == null:
		return super(x, z)
	var height := map_height_at(x, z)
	# Little bumps on top. They fade out at the water's edge, so they never
	# make a hole in the shore, and trails only get a few.
	var bumps := map.bumps * clampf(height / 3.0, 0.0, 1.0)
	if ground_at(x, z) == Ground.TRAIL:
		bumps *= 0.3
	height += _bump_noise.get_noise_2d(x, z) * bumps
	# A flat spot where you start.
	var from_start := Vector2(x - map.start.x, z - map.start.y).length()
	height = lerpf(_start_height, height, smoothstep(spawn_flat_radius, spawn_flat_radius + 40.0, from_start))
	# Walls at the edge of the map, like on the Explore map.
	var edge := maxf(absf(x), absf(z)) / (size / 2.0)
	return height + smoothstep(0.94, 1.0, edge) * edge_wall_height


func _surface_id(x: float, z: float, height: float, height_x: float, height_z: float) -> int:
	if map == null:
		return super(x, z, height, height_x, height_z)
	if height < WATER_LEVEL - 0.05:
		return WATER
	var ground := ground_at(x, z)
	if ground == Ground.TRAIL or Vector2(x - map.start.x, z - map.start.y).length() < spawn_flat_radius:
		return TRACK
	var up := Vector3(height - height_x, 1.0, height - height_z).normalized().y
	if up < _rock_limit:
		return ROCK
	var surface: int = DIRT
	if ground == Ground.SAND:
		surface = SAND
	elif ground != Ground.FOREST:
		# Open ground: meadows low down, then more and more rock, then snow.
		var how_high := height / map.highest
		if how_high > map.snow_line:
			return SNOW
		var rockiness := inverse_lerp(map.meadow_line, map.rock_line, how_high)
		if _patch_noise.get_noise_2d(x, z) * 2.0 + 0.5 > rockiness:
			surface = MEADOW
		else:
			surface = ROCK
	if surface != ROCK and surface != SAND and _mud_noise.get_noise_2d(x, z) > mud_amount:
		return MUD
	return surface


func _chunk_material() -> Material:
	return map_ground_material if map else ground_material


# On a map, each surface is painted in its own colour (map_terrain.gdshader).
func _surface_color(surface_id: int) -> Color:
	if map == null:
		return super(surface_id)
	return _surfaces[surface_id].color


func get_surface_at(world_position: Vector3) -> SurfaceType:
	if map == null:
		return super(world_position)
	var local := to_local(world_position)
	return _surfaces[surface_id_at(local.x, local.z)]


## How likely a tree is to grow at (x, z), from 0 to 1 (map_nature.gd asks).
func tree_chance_at(x: float, z: float) -> float:
	var height := height_at(x, z)
	var chance := 0.0
	match surface_id_at(x, z):
		DIRT:
			chance = map.trees_in_forest
		MEADOW:
			chance = map.trees_in_open
		SAND:
			chance = map.trees_on_sand
		TRACK, ROCK, SNOW, WATER:
			return 0.0
	# Close to the water, and not much higher than it (an oasis).
	if height < 3.0:
		chance = maxf(chance, map.trees_by_water)
	return chance


## How likely a bush is to grow at (x, z), from 0 to 1.
func bush_chance_at(x: float, z: float) -> float:
	match surface_id_at(x, z):
		DIRT:
			return 0.8
		MEADOW:
			return 0.5
		SAND:
			return 0.06
		ROCK:
			return 0.08
	return 0.0


## How likely a rock is to lie at (x, z), from 0 to 1.
func rock_chance_at(x: float, z: float, boulder: bool) -> float:
	match surface_id_at(x, z):
		ROCK:
			return 1.0
		SNOW:
			return 0.15
		TRACK, WATER, MUD:
			return 0.0
	return 0.25 if boulder else 0.5


## The map screen shows the poster instead of a drawing of the ground.
func make_map_image(pixels: int) -> Image:
	if map == null or map.poster == null:
		return super(pixels)
	var image := map.poster.duplicate()
	image.resize(pixels, pixels)
	return image


# One flat sheet of water over the whole map, at WATER_LEVEL.
func _add_water() -> void:
	if _water:
		_water.queue_free()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(map.water_color, 0.82)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.15
	material.metallic_specular = 0.7
	plane.material = material
	_water = MeshInstance3D.new()
	_water.name = "Water"
	_water.mesh = plane
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.position.y = WATER_LEVEL
	add_child(_water)
