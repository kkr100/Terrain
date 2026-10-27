class_name ExperimentalMap
extends Node
## Sets up Experimental mode for the map you picked on the map-select screen
## (scenes/experimental_select.tscn, see ExperimentalMaps).
##
## This is the first node in experimental.tscn. Godot runs _ready() on nodes
## in the order of the Scene panel, so this runs before the terrain, the
## trees and the places are built, and can change their settings first.
##
## While you drive it also checks that the car isn't under water.

@export var terrain: MapTerrain
@export var nature: MapNature
@export var points_root: Node3D
@export var exploration: Exploration
## The HUD (explore_hud.gd): it shows the map's name when you start.
@export var hud: CanvasLayer
@export var map_screen: ExploreMap
@export var world_environment: WorldEnvironment

@export_group("Scenery")
## Trees for maps whose "trees" is "pines".
@export var pine_scenes: Array[PackedScene] = []
## Trees for maps whose "trees" is "palms".
@export var palm_scenes: Array[PackedScene] = []
## Boulders and bushes for the desert maps.
@export var desert_boulder_scenes: Array[PackedScene] = []
@export var desert_bush_scenes: Array[PackedScene] = []

## If the car is this far under the water, it's put back on land.
@export var too_deep := 1.3

## The NatureModels colours for the desert: drier leaves, sandy stones.
const DESERT_PALETTE := {
	"leafsGreen": Color(0.5, 0.6, 0.24),
	"leafsDark": Color(0.36, 0.48, 0.2),
	"woodBark": Color(0.55, 0.4, 0.26),
	"woodBarkDark": Color(0.45, 0.32, 0.2),
	"woodInner": Color(0.86, 0.7, 0.46),
	"wood": Color(0.66, 0.47, 0.3),
	"woodDark": Color(0.47, 0.33, 0.22),
	"grass": Color(0.62, 0.6, 0.3),
	"stone": Color(0.78, 0.56, 0.4),
	"stoneDark": Color(0.64, 0.43, 0.32),
	"dirt": Color(0.6, 0.45, 0.3),
}

var map: ExploreMapData


func _ready() -> void:
	map = ExperimentalMaps.load_map(ExperimentalMaps.selected_index())
	terrain.map = map
	if map == null:
		# The copy of the Explore map: everything stays as it is in the scene.
		return

	# The car always starts in the middle of the world (where CarSpawner is).
	# So instead of moving the car to the map's start, we move the whole map,
	# so that its start ends up in the middle of the world.
	var start_height := terrain.map_height_at(map.start.x, map.start.y)
	terrain.position = Vector3(-map.start.x, -start_height, -map.start.y)

	# Put the places where the map says. They're moved onto the ground later
	# (by Exploration), so only x and z matter here.
	var points := points_root.get_children()
	for i in points.size():
		if i < map.places.size():
			var spot := map.places[i]
			points[i].position = terrain.position + Vector3(spot.x, 0.0, spot.y)
		else:
			# More places in the scene than the map has spots for.
			points[i].queue_free()
			points_root.remove_child(points[i])

	exploration.save_section = ExperimentalMaps.save_section(map)
	hud.start_title = map.display_name
	# The poster is detailed, so draw it bigger than the usual 256 pixels.
	map_screen.map_pixels = 1024

	_set_up_nature()
	_set_up_sky()


func _set_up_nature() -> void:
	if map.trees == "palms":
		nature.tree_scenes = palm_scenes
		nature.boulder_scenes = desert_boulder_scenes
		nature.bush_scenes = desert_bush_scenes
		nature.palette = DESERT_PALETTE
		nature.tree_height = Vector2(6.0, 11.0)
	else:
		nature.tree_scenes = pine_scenes
	nature.tree_count = map.tree_count
	nature.rock_count = map.rock_count
	nature.boulder_count = map.boulder_count


func _set_up_sky() -> void:
	# The scene's sky is shared by everyone who loads the scene, so we change
	# a copy of it ("duplicate(true)" copies the sky inside it too).
	var environment := world_environment.environment.duplicate(true)
	environment.fog_light_color = map.fog
	environment.fog_density = map.fog_density
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	if sky_material:
		sky_material.sky_top_color = map.sky_top
		sky_material.sky_horizon_color = map.sky_horizon
		sky_material.ground_horizon_color = map.sky_horizon
		sky_material.ground_bottom_color = map.sky_ground
	world_environment.environment = environment


func _physics_process(_delta: float) -> void:
	if map == null or exploration.car == null:
		return
	# Cars can't swim. If it went into deep water, put it back on land.
	var car := exploration.car
	var water_height := terrain.global_position.y + MapTerrain.WATER_LEVEL
	if car.global_position.y < water_height - too_deep:
		car.respawn()
