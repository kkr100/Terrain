class_name Upgrades
## The list of car upgrades, which ones you've unlocked, and which ones are
## fitted to each car.
##
## You unlock an upgrade by finding the point of interest it belongs to in
## Explore mode, so there's nothing extra to save for that: we just look at
## the places you found. What we do save is which upgrades you fitted to
## which car, in the [upgrades] section of user://save.cfg.
##
## To add an upgrade: duplicate one of the .tres files in upgrades/, give it
## a new id and numbers, and add its path to PATHS below.

## In the order the car-select screen shows them.
const PATHS := [
	"res://upgrades/tuned_engine.tres",
	"res://upgrades/turbo.tres",
	"res://upgrades/crawler_gears.tres",
	"res://upgrades/rally_tyres.tres",
	"res://upgrades/all_terrain_tyres.tres",
	"res://upgrades/mud_tyres.tres",
	"res://upgrades/rally_suspension.tres",
	"res://upgrades/anti_roll_bars.tres",
	"res://upgrades/lift_kit.tres",
	"res://upgrades/light_panels.tres",
	"res://upgrades/rally_wing.tres",
	"res://upgrades/nitro.tres",
]

## The slots, in the order the car-select screen shows them.
const SLOTS := ["Engine", "Tyres", "Suspension", "Body"]

const SAVE_PATH := "user://save.cfg"


## Every upgrade (loaded from PATHS).
static func all() -> Array[CarUpgrade]:
	var list: Array[CarUpgrade] = []
	for path in PATHS:
		list.append(load(path))
	return list


## The upgrades that go in one slot ("Engine", "Tyres", ...).
static func in_slot(slot: String) -> Array[CarUpgrade]:
	return all().filter(func(upgrade: CarUpgrade) -> bool: return upgrade.slot == slot)


static func find(id: String) -> CarUpgrade:
	for upgrade in all():
		if upgrade.id == id:
			return upgrade
	return null


## The upgrade you get for finding the place with this id, or null.
static func unlocked_by_place(place_id: String) -> CarUpgrade:
	for upgrade in all():
		if upgrade.unlocked_by == place_id:
			return upgrade
	return null


static func is_unlocked(upgrade: CarUpgrade) -> bool:
	return unlock_all_on() or Exploration.load_found().has(upgrade.unlocked_by)


## True if the dev console's "unlock_all" command is switched on. It's a
## separate flag in the [dev] section of user://save.cfg, so it doesn't
## pretend you found places you never drove to: "relock" switches it off and
## everything you really found stays unlocked.
static func unlock_all_on() -> bool:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)
	return file.get_value("dev", "unlock_all", false)


static func set_unlock_all(on: bool) -> void:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)  # Keep anything else that's already saved.
	file.set_value("dev", "unlock_all", on)
	file.save(SAVE_PATH)


static func unlocked_count() -> int:
	var count := 0
	for upgrade in all():
		if is_unlocked(upgrade):
			count += 1
	return count


## The upgrades fitted to the car called car_id ("rally", "suv", ...).
static func fitted(car_id: String) -> Array[CarUpgrade]:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)
	# Saved as {"Engine": "turbo", "Tyres": "mud_tyres", ...}.
	var ids: Dictionary = file.get_value("upgrades", car_id, {})
	var list: Array[CarUpgrade] = []
	for slot in SLOTS:
		var upgrade := find(ids.get(slot, ""))
		# Skip it if it's not unlocked (for example if the save was reset).
		if upgrade and is_unlocked(upgrade):
			list.append(upgrade)
	return list


## Fits an upgrade to a car, in place of whatever was in that slot before.
## Pass null to put the stock part back.
static func fit(car_id: String, slot: String, upgrade: CarUpgrade) -> void:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)  # Keep anything else that's already saved.
	var ids: Dictionary = file.get_value("upgrades", car_id, {})
	if upgrade:
		ids[slot] = upgrade.id
	else:
		ids.erase(slot)
	file.set_value("upgrades", car_id, ids)
	file.save(SAVE_PATH)
