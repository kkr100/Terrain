extends Node3D
## The exhaust pipes of the nitro upgrade, and the blue flames that shoot out
## of them while you boost. The flames flicker a little so they look alive.

var _car: Car

@onready var _flames: Node3D = $Flames


func _ready() -> void:
	# We're somewhere inside the car (on its "Exhaust" mount), so walk up the
	# scene tree until we find it.
	var node := get_parent()
	while node != null and not node is Car:
		node = node.get_parent()
	_car = node as Car
	_flames.hide()


func _process(_delta: float) -> void:
	_flames.visible = _car != null and _car.is_boosting
	if _flames.visible:
		# The flames point backwards (-Z), so stretching Z makes them longer.
		_flames.scale.z = randf_range(0.7, 1.2)
