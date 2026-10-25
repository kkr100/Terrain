@tool
class_name TintModel
extends Node3D
## Put this script on a model to tint all its colours, for example to make
## a car look old and rusty. The tint is multiplied with the model's own
## colours: white changes nothing, orange-brown makes everything rusty.

@export var tint := Color(1, 1, 1):
	set(value):
		tint = value
		if is_inside_tree():
			_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(i) as BaseMaterial3D
			if material == null:
				continue
			# A copy, so other models using the same material don't change too.
			material = material.duplicate()
			material.albedo_color = material.albedo_color * tint
			material.roughness = 1.0
			mesh_instance.set_surface_override_material(i, material)
