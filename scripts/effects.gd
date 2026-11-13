class_name Effects
extends RefCounted
## Small visual helpers built from primitives (no imported assets) plus the
## shared "who can be hit" query used by area moves and the tornado.


## Everyone except `user` that can take a hit right now: benders and targets.
static func hittables(user: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var tree := user.get_tree()
	for group in ["benders", "targets"]:
		for node in tree.get_nodes_in_group(group):
			if node == user or not node is Node3D or not node.has_method("take_hit"):
				continue
			if node.has_method("is_alive") and not node.is_alive():
				continue
			found.append(node)
	return found


## A flat ring that grows to `radius` and fades out. Shows the size of area moves.
static func ring(parent: Node, at: Vector3, radius: float, color: Color, seconds: float) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.82
	mesh.outer_radius = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.85)
	material.emission_enabled = true
	material.emission = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.global_position = at
	instance.scale = Vector3.ONE * 0.2
	var tween := instance.create_tween().set_parallel()
	tween.tween_property(instance, "scale", Vector3(radius, 1.0, radius), seconds)
	tween.tween_property(material, "albedo_color:a", 0.0, seconds)
	tween.chain().tween_callback(instance.queue_free)


## Floating number that rises and fades, for damage (red) or healing (green).
static func number(parent: Node, at: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.004
	label.outline_size = 12
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = at + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position:y", at.y + 1.2, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
