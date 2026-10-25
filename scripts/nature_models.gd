class_name NatureModels
## Helpers for using Kenney's Nature Kit models, shared by the race map's
## scenery (nature.gd), the Explore map's scenery (explore_nature.gd) and the
## points of interest (point_of_interest.gd).

## Kenney's Nature Kit is coloured teal and orange. We repaint it to fit our
## green hills: each material name in the models gets the colour listed here.
const PALETTE := {
	"leafsGreen": Color(0.42, 0.66, 0.25),
	"leafsDark": Color(0.2, 0.46, 0.24),
	"woodBark": Color(0.52, 0.34, 0.2),
	"woodBarkDark": Color(0.42, 0.28, 0.18),
	"woodInner": Color(0.86, 0.7, 0.46),
	"wood": Color(0.66, 0.47, 0.3),
	"woodDark": Color(0.47, 0.33, 0.22),
	"grass": Color(0.4, 0.64, 0.24),
	"stone": Color(0.6, 0.6, 0.62),
	"stoneDark": Color(0.46, 0.46, 0.5),
	"dirt": Color(0.55, 0.4, 0.27),
}


## Loads a model and works out what we need from it: its mesh (with matte,
## repainted materials), its collision points, and how big it is at scale 1.
## Returns an empty Dictionary if the scene has no mesh.
static func load_kind(scene: PackedScene, palette: Dictionary) -> Dictionary:
	if scene == null:
		return {}
	var root := scene.instantiate()
	var mesh_instance := _find_mesh_instance(root)
	var result := {}
	if mesh_instance:
		var mesh := mesh_instance.mesh
		var aabb := mesh.get_aabb()
		# create_convex_shape(true, true) makes a simplified convex hull: few
		# points, cheap for the physics engine.
		var hull: ConvexPolygonShape3D = mesh.create_convex_shape(true, true)
		# A copy of the mesh with our own materials. Kenney's models are plain
		# colours, one material per colour. We give each material its colour
		# from the palette, make it fully matte, and let it take a tint from a
		# MultiMesh (instance colour) so every tree can be a slightly
		# different shade.
		var painted: ArrayMesh = mesh.duplicate()
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i)
			if material is StandardMaterial3D:
				material = material.duplicate()
				if palette.has(material.resource_name):
					material.albedo_color = palette[material.resource_name]
				material.roughness = 1.0
				material.vertex_color_use_as_albedo = true
			painted.surface_set_material(i, material)
		result = {
			"mesh": painted,
			"points": hull.points,
			# Where the model's bottom is, so we can put it on the ground.
			"bottom": aabb.position.y,
			"radius": maxf(aabb.size.x, aabb.size.z) * 0.5,
			"height": aabb.size.y,
		}
	root.free()
	return result


## Gives every Nature Kit material under "node" its colour from the palette.
## For models placed by hand, like the ones in the points of interest.
static func repaint(node: Node, palette: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material is StandardMaterial3D and palette.has(material.resource_name):
				material = material.duplicate()
				material.albedo_color = palette[material.resource_name]
				material.roughness = 1.0
				node.set_surface_override_material(i, material)
	for child in node.get_children():
		repaint(child, palette)


## A colour close to white, to tint a model a little lighter or darker.
static func random_tint(rng: RandomNumberGenerator, amount: float) -> Color:
	var shade := rng.randf_range(1.0 - amount, 1.0)
	return Color(shade * rng.randf_range(0.92, 1.0), shade, shade * rng.randf_range(0.9, 1.0))


static func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null
