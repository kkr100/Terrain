@tool
class_name PointOfInterest
extends Node3D
## A place to discover in Explore mode: a campsite, a wreck, an old tower...
##
## Each one is its own little scene in scenes/poi/. Open one to see how it's
## put together: it's just Kenney models, moved, turned and scaled by hand.
## Then explore.tscn places them all over the big map.
##
## To add a new one: duplicate a scene in scenes/poi/, change the models and
## the settings below (give it a new "id"!), then drag it under the
## "PointsOfInterest" node in explore.tscn. You only need to set X and Z:
## when the game starts, it's moved onto the ground.
##
## When the game starts this script also:
## - repaints the Nature Kit models in our colours (see nature_models.gd),
## - gives every big model a simple collision shape, so the car bumps into
##   it instead of driving through. To leave something out (like the water
##   of a pond), add it to the group "no_collision" (Node panel > Groups).

## A short name the save file remembers. Don't change it once players found
## it, or they'll have to find it again!
@export var id := ""
## The name shown when you find it.
@export var display_name := "Somewhere"
## One line about it, shown when you find it.
@export_multiline var description := ""
## You discover it when the car gets this close, in metres.
@export var discover_radius := 28.0
## The ground is made flat this far around it, and no trees or rocks grow
## there, in metres.
@export var flat_radius := 18.0
## Dig a bowl this deep into the flat ground, in metres (for a pond).
@export var basin_depth := 0.0


func _ready() -> void:
	NatureModels.repaint(self, NatureModels.PALETTE)
	if not Engine.is_editor_hint():
		_add_collision()


func _add_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or _skip_collision(mesh_instance):
			continue
		# Where the mesh is, compared to this point of interest.
		var xform := global_transform.affine_inverse() * mesh_instance.global_transform
		var size := (xform * mesh_instance.mesh.get_aabb()).size
		# Tiny things (bottles, lily pads) don't need collision.
		if maxf(size.x, maxf(size.y, size.z)) < 1.0:
			continue
		var hull: ConvexPolygonShape3D = mesh_instance.mesh.create_convex_shape(true, true)
		# Physics doesn't like scaled shapes, so we move each point instead.
		var points := PackedVector3Array()
		for point in hull.points:
			points.append(xform * point)
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)


# True if this node, or one of its parents inside the point of interest, is
# in the "no_collision" group.
func _skip_collision(node: Node) -> bool:
	while node != self and node != null:
		if node.is_in_group("no_collision"):
			return true
		node = node.get_parent()
	return false
