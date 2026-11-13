class_name WallAbility
extends Ability
## Stone Wall: raises a slab of stone in front of the user that blocks movement
## and shots for "duration" seconds, then sinks back into the floor.


func _activate() -> void:
	var direction: Vector3 = user.aim_direction()
	user.face(direction)
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
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(str(stats.get("color", "#7d7064")))
	material.roughness = 0.95
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


func reach() -> float:
	return 14.0
