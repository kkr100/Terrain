extends Label
## Shows the car's speed and the controls in the top-left corner.

## The car whose speed we show. Set this in the Inspector.
@export var car: VehicleBody3D

const CONTROLS := "W / Up: drive   S / Down: brake, reverse   A D / Left Right: steer\nSpace: handbrake   R: flip the car back up"


func _process(_delta: float) -> void:
	if car == null:
		return
	# linear_velocity is in metres per second. Multiply by 3.6 for km/h.
	var kmh := absf(car.get_forward_speed()) * 3.6
	var ground: String = car.surface_name if car.surface_name != "" else "In the air"
	text = "%d km/h   %s\n%s" % [roundi(kmh), ground, CONTROLS]
