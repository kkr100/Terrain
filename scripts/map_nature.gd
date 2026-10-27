class_name MapNature
extends ExploreNature
## Trees, rocks and bushes for Experimental mode. It's the Explore map's
## scenery (explore_nature.gd), but on a map made from a poster the terrain
## says where things grow: trees in the poster's forests (or palms by the
## water in the desert), boulders on the rocks, nothing on the trails or in
## the lakes. See MapTerrain.tree_chance_at() and the others.
##
## With no map (the copy of the Explore map), it's exactly ExploreNature.

## The colours to repaint the models in (see NatureModels.PALETTE).
## ExperimentalMap gives the desert maps drier, sandier colours.
@export var palette := NatureModels.PALETTE

# The terrain, if it is a MapTerrain with a map (null otherwise).
var _map_terrain: MapTerrain


func _ready() -> void:
	_map_terrain = terrain as MapTerrain
	if _map_terrain and _map_terrain.map == null:
		_map_terrain = null
	if _map_terrain:
		# The start is wherever the map says, not in the middle of the map.
		var start := _map_terrain.map.start
		_clear_spots.append(Vector3(start.x, start.y, start_clearance))
	super()


func _load_kinds(scenes: Array[PackedScene]) -> Array:
	var kinds := []
	for scene in scenes:
		var kind := NatureModels.load_kind(scene, palette)
		if not kind.is_empty():
			kinds.append(kind)
	return kinds


func _wants_rock(rng: RandomNumberGenerator, spot: Vector3, prefer_rock: bool) -> bool:
	if _map_terrain == null:
		return super(rng, spot, prefer_rock)
	return rng.randf() < _map_terrain.rock_chance_at(spot.x, spot.z, prefer_rock)


func _wants_tree(rng: RandomNumberGenerator, spot: Vector3) -> bool:
	if _map_terrain == null:
		return super(rng, spot)
	return rng.randf() < _map_terrain.tree_chance_at(spot.x, spot.z)


func _wants_bush(rng: RandomNumberGenerator, spot: Vector3) -> bool:
	if _map_terrain == null:
		return super(rng, spot)
	# The forest noise still makes some patches thicker than others.
	var chance := _map_terrain.bush_chance_at(spot.x, spot.z)
	if _forest_noise.get_noise_2d(spot.x, spot.z) < -0.15:
		chance *= 0.3
	return rng.randf() < chance
