class_name ExperimentalMaps
## The maps you can pick in Experimental mode, and which one you picked last.
##
## The first five are made from map posters by tools/make_explore_maps.py.
## The last one is the old Experimental map: a copy of the Explore map.
##
## To add a map: make its .tres (with the tool, or by duplicating one in
## assets/maps/ and pointing it at your own pictures) and add its path here.

const MAPS := [
	"res://assets/maps/tassili/tassili.tres",
	"res://assets/maps/aures/aures.tres",
	"res://assets/maps/emerald_lake/emerald_lake.tres",
	"res://assets/maps/gimli_ridge/gimli_ridge.tres",
	"res://assets/maps/asgard_mountain/asgard_mountain.tres",
	# An empty path means "no map file": the copy of the Explore map.
	"",
]

## The name and save-file id of the copy of the Explore map. It keeps the
## "experimental" save section it always had.
const EXPLORE_COPY_NAME := "Explore copy"
const EXPLORE_COPY_ID := "experimental"

const SAVE_PATH := "user://save.cfg"


## The map at position "index" in MAPS, or null for the copy of Explore.
static func load_map(index: int) -> ExploreMapData:
	if MAPS[index] == "":
		return null
	return load(MAPS[index])


## The position in MAPS of the map you picked last time (the first if none).
static func selected_index() -> int:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)
	var path: String = file.get_value("experimental", "map", MAPS[0])
	return maxi(MAPS.find(path), 0)


static func select(index: int) -> void:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)  # Keep anything else that's already saved.
	file.set_value("experimental", "map", MAPS[index])
	file.save(SAVE_PATH)


## The section of user://save.cfg where a map's found places are saved.
static func save_section(map: ExploreMapData) -> String:
	return EXPLORE_COPY_ID if map == null else "experimental_" + map.id
