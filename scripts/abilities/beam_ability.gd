class_name BeamAbility
extends Ability
## Lightning: gather energy for "windup" seconds (rooted in place, sparks in
## your hands), then a bolt strikes instantly along your aim and hits the first
## thing in its path.

var _charge: CPUParticles3D


func _activate() -> void:
	var windup := float(stats.get("windup", 0.4))
	user.face_aim(user.aim_direction())
	user.animate(str(stats.get("anim", "channel")), windup + 0.25, true)
	user.root(windup)
	_charge = Effects.emitter(Color(0.85, 0.95, 1.0), Color(0.4, 0.6, 1.0, 0.0), {
		"amount": 30, "lifetime": 0.25, "size": 0.08, "speed": Vector2(1.0, 3.0), "spread": 180.0,
		"emit_radius": 0.25})
	Effects.attach(user, _charge, windup, Vector3(0, 1.2, 0))
	var tween := create_tween()
	tween.tween_interval(windup)
	tween.tween_callback(_strike)


func _strike() -> void:
	if not user.can_act():
		return
	var direction: Vector3 = user.aim_direction()
	user.face_aim(direction)
	var from := user.muzzle()
	var to := from + direction * float(stats.get("range", 30.0))
	var query := PhysicsRayQueryParameters3D.create(from, to, 7, [user.get_rid()])
	query.collide_with_areas = false
	var hit := user.get_world_3d().direct_space_state.intersect_ray(query)
	var end := to
	if not hit.is_empty():
		end = hit["position"]
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("take_hit"):
			collider.take_hit({
				"damage": float(stats.get("damage", 30.0)),
				"knockback": float(stats.get("knockback", 0.0)),
				"direction": Vector3(direction.x, 0.0, direction.z).normalized(),
				"attacker": user,
			})
	var color := Color(str(stats.get("color", "#9fd0ff")))
	Effects.bolt(user.get_parent(), from, end, color, 0.3)
	Effects.flash(user.get_parent(), from.lerp(end, 0.5), color, 6.0, 14.0, 0.35)
	Effects.burst(user.get_parent(), end, Color(1, 1, 1), Color(color, 0.0), {
		"amount": 24, "lifetime": 0.35, "size": 0.12, "speed": Vector2(3.0, 8.0), "spread": 180.0})


func reach() -> float:
	return float(stats.get("range", 30.0))
