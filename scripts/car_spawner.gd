class_name CarSpawner
extends Marker3D
## Puts the car you picked on the car-select screen at this spot when the
## level starts, and tells the camera and everything else which car it is.
##
## The car isn't part of the race levels or explore.tscn, because it depends on your
## choice. This node comes before the camera, the HUD and so on in the Scene
## panel, so its _ready runs first and the car is there before they need it.

@export var camera: Node3D
## Every node here has a "car" variable, and gets it set to the new car. In
## the race that's the Race and the HUD, in Explore the Exploration and its HUD.
@export var car_users: Array[Node] = []

## The car that was placed. Other scripts can use this.
var car: Car


func _ready() -> void:
	var scene: PackedScene = load(CarChoice.selected().scene)
	car = scene.instantiate()
	# The car becomes our child, so it starts exactly where this marker is.
	add_child(car)
	camera.target = car
	for node in car_users:
		node.car = car
