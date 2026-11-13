class_name ConeAbility
extends Ability
## Flame Breath: a short burst of fire in a cone where you aim. Hits everyone
## inside "range" and "angle_degrees" of the aim at once.


func _activate() -> void:
	var direction: Vector3 = user.aim_direction()
	user.face_aim(direction)
	user.animate(str(stats.get("anim", "push")))
	var reach_m := float(stats.get("range", 6.0))
	var half := deg_to_rad(float(stats.get("angle_degrees", 40.0)) * 0.5)
	var origin := user.muzzle()
	var flame := Effects.emitter(Color(1.0, 0.95, 0.6), Color(0.85, 0.12, 0.0, 0.0), {
		"amount": 90, "lifetime": 0.45, "size": 0.45, "direction": direction,
		"spread": rad_to_deg(half) * 0.8, "speed": Vector2(reach_m * 1.6, reach_m * 2.4),
		"damping": reach_m * 1.5, "emit_radius": 0.15, "end_scale": 2.2, "one_shot": true,
		"explosiveness": 0.55})
	user.get_parent().add_child(flame)
	flame.global_position = origin + direction * 0.4
	flame.emitting = true
	Effects.free_after(flame, 1.0)
	Effects.flash(user.get_parent(), origin + direction * reach_m * 0.5, Color(1.0, 0.55, 0.2), 5.0, reach_m, 0.45)
	for target: Node3D in Effects.hittables(user):
		var offset := target.global_position + Vector3.UP * 0.9 - origin
		if offset.length() > reach_m or offset.angle_to(direction) > half:
			continue
		var flat := Vector3(offset.x, 0.0, offset.z).normalized()
		target.take_hit({
			"damage": float(stats.get("damage", 10.0)),
			"knockback": float(stats.get("knockback", 0.0)),
			"direction": flat,
			"attacker": user,
		})


func reach() -> float:
	return float(stats.get("range", 6.0))
