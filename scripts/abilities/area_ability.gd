class_name AreaAbility
extends Ability
## Inferno Ring and Seismic Stomp: hits everyone within "radius" of the user
## at once, pushing them away from the centre.


func _activate() -> void:
	var radius := float(stats.get("radius", 5.0))
	var center := user.global_position
	Effects.ring(user.get_parent(), center + Vector3.UP * 0.1, radius,
		Color(str(stats.get("color", "#ffffff"))), 0.45)
	for target: Node3D in Effects.hittables(user):
		var offset := target.global_position - center
		offset.y = 0.0
		if offset.length() > radius:
			continue
		var direction := offset.normalized() if offset.length() > 0.01 else user.facing()
		target.take_hit({
			"damage": float(stats.get("damage", 10.0)),
			"knockback": float(stats.get("knockback", 0.0)),
			"slow": float(stats.get("slow", 0.0)),
			"slow_time": float(stats.get("slow_time", 0.0)),
			"direction": direction,
			"attacker": user,
		})


func reach() -> float:
	return float(stats.get("radius", 5.0))
