class_name PillarAbility
extends Ability
## Earth Column: a pillar of rock bursts out of the floor where you aim (a ring
## warns first), launching anyone standing there into the air. The pillar
## stays a few seconds as cover, then sinks.


func _activate() -> void:
	var point: Vector3 = user.aim_point(float(stats.get("range", 16.0)))
	user.face_aim(point - user.global_position)
	user.animate(str(stats.get("anim", "raise")))
	var radius := float(stats.get("radius", 1.4))
	Effects.ring(user.get_parent(), point + Vector3.UP * 0.05, radius, Color(0.9, 0.7, 0.4), 0.35)
	Effects.dust(user.get_parent(), point, 0.6)
	var tween := create_tween()
	tween.tween_interval(float(stats.get("delay", 0.35)))
	tween.tween_callback(_erupt.bind(point))


func _erupt(point: Vector3) -> void:
	if not is_instance_valid(user) or not user.is_inside_tree():
		return
	var radius := float(stats.get("radius", 1.4))
	var height := float(stats.get("height", 2.6))
	var color := Color(str(stats.get("color", "#8a6a45")))
	Effects.area_hit(user, point, radius, {
		"damage": float(stats.get("damage", 14.0)),
		"launch": float(stats.get("launch", 9.0)),
		"knockback": float(stats.get("knockback", 2.0)),
	})
	var column := AnimatableBody3D.new()
	column.name = "EarthColumn"
	column.add_to_group("spawned")
	column.collision_layer = 1
	column.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = radius * 0.75
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = height * 0.5
	column.add_child(collision)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.6
	mesh.bottom_radius = radius * 0.8
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 2
	var rock := Effects.mesh_instance(mesh, Effects.mat(color))
	rock.position.y = height * 0.5
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	column.add_child(rock)
	var cap := Effects.mesh_instance(Effects.cone(radius * 0.62, 0.5, 6), Effects.mat(color.lightened(0.1)))
	cap.position.y = height + 0.25
	column.add_child(cap)
	user.get_parent().add_child(column)
	column.global_position = Vector3(point.x, -height, point.z)
	column.rotation.y = randf() * TAU
	var tween := column.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(column, "global_position:y", 0.0, 0.12)
	tween.tween_interval(float(stats.get("duration", 3.0)))
	tween.tween_property(column, "global_position:y", -height, 0.4)
	tween.tween_callback(column.queue_free)
	Effects.debris(user.get_parent(), point + Vector3.UP * 0.3, color, 1.2)
	Effects.ring(user.get_parent(), point + Vector3.UP * 0.05, radius * 2.0, Color(0.8, 0.7, 0.55), 0.4)


func reach() -> float:
	return float(stats.get("range", 16.0))
