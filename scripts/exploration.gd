class_name Exploration
extends Node
## The rules of Explore mode: drive around freely and find all the points of
## interest. Which ones you found is saved, so you can keep exploring next
## time where you left off.
##
## There's no countdown and no timer. This node just checks every physics
## frame whether the car is close to a point of interest it hasn't found yet.

## Sent when the car finds a new point of interest.
signal discovered(point: PointOfInterest)
## Sent once you've found every point of interest.
signal all_discovered

## The car. CarSpawner fills this in.
@export var car: Car
@export var terrain: ExploreTerrain
## The node whose children are the points of interest.
@export var points_root: Node3D
## If the car ends up this far below the ground (fell through the world),
## it's put back.
@export var fall_limit := 15.0
## The section of user://save.cfg where the places you found are saved.
## Explore uses "explore". Experimental mode uses "experimental", so testing a
## new map there never changes your real Explore progress.
@export var save_section := "explore"
## Whether finding a place unlocks its car upgrade. Only in real Explore mode:
## upgrades are unlocked by the places in the "explore" save section.
@export var unlocks_upgrades := true

const SAVE_PATH := "user://save.cfg"

var points: Array[PointOfInterest] = []
## The ids of the points of interest you've found: id -> true.
var found := {}


func _ready() -> void:
	for child in points_root.get_children():
		if child is PointOfInterest:
			points.append(child)
			# Stand it on the (flattened) ground. If the terrain dug a bowl
			# for a pond, that's deeper in the middle, so we add that back.
			child.global_position.y = terrain.get_height_at(child.global_position) + child.basin_depth
	for id in load_found(save_section):
		found[id] = true
	# Remember how many there are, so the main menu can show "3 / 12".
	var file := ConfigFile.new()
	file.load(SAVE_PATH)
	file.set_value(save_section, "total", points.size())
	file.save(SAVE_PATH)
	# The car's own "fell off the map" check uses a fixed height, which doesn't
	# work on a map with deep valleys. We check against the ground instead.
	car.fall_limit_y = -INF


func _physics_process(_delta: float) -> void:
	var car_position := car.global_position
	if car_position.y < terrain.get_height_at(car_position) - fall_limit:
		car.respawn()
	for point in points:
		if found.has(point.id):
			continue
		var offset := point.global_position - car_position
		offset.y = 0.0
		if offset.length() < point.discover_radius:
			_discover(point)


func is_found(point: PointOfInterest) -> bool:
	return found.has(point.id)


func _discover(point: PointOfInterest) -> void:
	found[point.id] = true
	save_found(found.keys(), save_section)
	# If you get stuck or fall, you're put back near the last place you found,
	# on the side you came from, facing it.
	var away := car.global_position - point.global_position
	away.y = 0.0
	var spot := point.global_position + away.normalized() * (point.flat_radius + 4.0)
	spot.y = terrain.get_height_at(spot) + 1.5
	car.set_respawn_point(spot, point.global_position)
	discovered.emit(point)
	if found.size() >= points.size():
		all_discovered.emit()


## The ids of all points of interest found so far (from the save file).
## Leave out section to get the ones from Explore mode.
static func load_found(section := "explore") -> Array:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return []
	return file.get_value(section, "found", [])


static func save_found(ids: Array, section := "explore") -> void:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)  # Keep anything else that's already saved.
	file.set_value(section, "found", ids)
	file.save(SAVE_PATH)


## How many points of interest there are, or 0 if you never played Explore.
static func total_count(section := "explore") -> int:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return 0
	return file.get_value(section, "total", 0)
