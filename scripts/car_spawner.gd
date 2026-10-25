class_name CarSpawner
extends Marker3D
## Puts the car you picked on the car-select screen at this spot when the race
## starts, and tells the camera, the race and the HUD which car it is.
##
## The car isn't part of main.tscn any more, because it depends on your
## choice. This node comes before the camera, race and HUD in the Scene panel,
## so its _ready runs first and the car is there before they need it.

@export var camera: Node3D
@export var race: Race
@export var hud: Node

## The car that was placed. Other scripts can use this.
var car: Car


func _ready() -> void:
	var scene: PackedScene = load(CarChoice.selected().scene)
	car = scene.instantiate()
	# The car becomes our child, so it starts exactly where this marker is.
	add_child(car)
	camera.target = car
	race.car = car
	hud.car = car
