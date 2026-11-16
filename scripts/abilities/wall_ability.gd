class_name WallAbility
extends Ability
## Stone Wall and Ice Wall: raises a slab in front of the user that blocks
## movement and shots for "duration" seconds, then sinks back into the floor.
## "look": "ice" makes it translucent ice.


func _activate() -> void:
	var direction: Vector3 = user.flat_aim()
	user.face_aim(direction)
	user.animate(str(stats.get("anim", "raise")))
	var ice := str(stats.get("look", "stone")) == "ice"
	var width := float(stats.get("width", 3.0))
	var height := float(stats.get("height", 2.6))
	var wall := StaticBody3D.new()
	wall.name = "StoneWall"
	wall.add_to_group("spawned")
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.8)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = height * 0.5
	wall.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	var color := Color(str(stats.get("color", "#7d7064")))
	var material := Effects.mat(Color(color, 0.75) if ice else color, 0.5 if ice else 0.0)
	if ice:
		material.roughness = 0.1
		material.metallic_specular = 1.0
	mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position.y = height * 0.5
	wall.add_child(mesh_instance)
	user.get_parent().add_child(wall)
	var spot := user.global_position + direction * float(stats.get("distance", 2.5))
	wall.global_position = Vector3(spot.x, -height, spot.z)
	wall.look_at(wall.global_position + direction, Vector3.UP)
	var tween := wall.create_tween()
	tween.tween_property(wall, "global_position:y", 0.0, 0.15)
	tween.tween_interval(float(stats.get("duration", 6.0)))
	tween.tween_property(wall, "global_position:y", -height, 0.3)
	tween.tween_callback(wall.queue_free)
	if ice:
		Effects.shatter(user.get_parent(), Vector3(spot.x, 0.5, spot.z), color, 1.2)
		Effects.splash(user.get_parent(), Vector3(spot.x, 0.2, spot.z), color, 1.2)
	else:
		Effects.debris(user.get_parent(), Vector3(spot.x, 0.2, spot.z), color, 1.3)


func reach() -> float:
	return 14.0
