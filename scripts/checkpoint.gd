class_name Checkpoint
extends Area3D
## One checkpoint: a tall beam of light that the car has to drive through.
##
## An Area3D is an invisible zone. It doesn't block anything, it just notices
## when a physics body (like our car) enters it and sends the "body_entered"
## signal. Race (scripts/race.gd) tells each checkpoint which state it is in,
## and listens for our "reached" signal.

## Sent when the car drives into this checkpoint while it's the next one.
signal reached(checkpoint: Checkpoint)

enum State {
	WAITING,  ## Not yet: shown as a thin, faint beam.
	NEXT,  ## The one to drive to now: a big bright beam.
	DONE,  ## Already passed: hidden.
}

## Colour of the beam when this is the next checkpoint.
@export var next_color := Color(1.0, 0.8, 0.1, 0.45)
## Colour of the beam when this is the next checkpoint *and* the finish line.
@export var finish_color := Color(0.2, 1.0, 0.35, 0.45)
## Colour of the beam for checkpoints that come later.
@export var waiting_color := Color(1.0, 1.0, 1.0, 0.12)

var state := State.WAITING

@onready var _beam: MeshInstance3D = $Beam
@onready var _ring: MeshInstance3D = $Ring


func _ready() -> void:
	# Connect the built-in signal to our function, so it runs every time a
	# body enters the area.
	body_entered.connect(_on_body_entered)


## Changes how the checkpoint looks. Race calls this.
func set_state(new_state: State, is_finish := false) -> void:
	state = new_state
	visible = state != State.DONE
	# The material is shared by the beam and the ring, so one change colours both.
	# It's marked "local to scene" in checkpoint.tscn, which gives every
	# checkpoint its own copy. Otherwise they would all change colour together.
	var material := _beam.material_override as StandardMaterial3D
	if state == State.NEXT:
		material.albedo_color = finish_color if is_finish else next_color
		_beam.scale = Vector3.ONE
		_ring.visible = true
	else:
		material.albedo_color = waiting_color
		# Make waiting beams thinner so the next one stands out.
		_beam.scale = Vector3(0.3, 1.0, 0.3)
		_ring.visible = false


func _on_body_entered(body: Node3D) -> void:
	if state == State.NEXT and body is VehicleBody3D:
		reached.emit(self)
