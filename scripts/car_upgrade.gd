class_name CarUpgrade
extends Resource
## One upgrade you can fit to a car, like a turbo or mud tyres.
##
## Like SurfaceType, this is a custom Resource: each upgrade is a small .tres
## file in upgrades/ that you can open and change in the Inspector. Finding a
## point of interest in Explore mode unlocks the upgrade whose "unlocked_by"
## is that place's id. Then you fit it on the car-select screen.
##
## The numbers don't replace the car's own settings, they change them. A
## power_scale of 1.25 gives every car 25% more power, so the light rally car
## and the heavy pickup still feel different after the same upgrade.
## 1.0 (or 0) means "no change".

## A short name the save file remembers. Don't change it once it's in use!
@export var id := ""
@export var display_name := "Upgrade"
## Which part of the car it goes on. A car can have one upgrade per slot.
@export_enum("Engine", "Tyres", "Suspension", "Body") var slot := "Engine"
## One line about what it does, shown on the car-select screen.
@export_multiline var description := ""
## The id of the point of interest that unlocks it (see scenes/poi/).
@export var unlocked_by := ""
## How the stat bars on the car-select screen change, like
## {"Acceleration": 1, "Top speed": -1}. Only for show.
@export var stat_bonus := {}

@export_group("Engine")
## Multiplies the engine's push. 1.25 = 25% more power.
@export var power_scale := 1.0
## Added to the top speed, in km/h. Can be negative.
@export var top_speed_add := 0.0
## Extra power while you hold the nitro key (Shift). 0.8 = 80% more. A full
## tank lasts a few seconds, then slowly fills up again. 0 = no nitro.
@export var boost_power := 0.0

@export_group("Tyres")
## Multiplies the grip on hard ground (dirt, rock).
@export var grip_scale := 1.0
## Multiplies the grip in mud (any ground that slows you down).
@export var mud_grip_scale := 1.0
## Multiplies how much mud slows the car. 0.5 = half as much.
@export var mud_drag_scale := 1.0
## Makes the tyres bigger (1.1 = 10% bigger), which also lifts the car.
@export var tire_size_scale := 1.0

@export_group("Suspension")
## Raises (or lowers, if negative) the car, in metres.
@export var ride_height_add := 0.0
## Multiplies how far the wheels can move up and down.
@export var travel_scale := 1.0
## Multiplies how stiff the springs are. Stiffer = less bouncy, harsher.
@export var stiffness_scale := 1.0
## Multiplies how much the car leans and rolls in turns. Smaller = flatter.
@export var roll_scale := 1.0

@export_group("Body")
## Multiplies the car's weight. 0.85 = 15% lighter.
@export var mass_scale := 1.0
## Pushes the car down onto the road at speed, for more grip in fast turns.
## 0.3 = an extra 30% of the car's weight at 100 km/h.
@export var downforce := 0.0

@export_group("Looks")
## An extra part to show on the car, like a wing or a light bar. It's a small
## scene in scenes/upgrade_parts/.
@export var part_scene: PackedScene
## Where on the car the part goes: each car scene has a "Mounts" node with a
## Marker3D for each of these, placed by hand to fit that car.
@export_enum("Roof", "Rear", "Exhaust") var part_mount := "Roof"
