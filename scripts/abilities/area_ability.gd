class_name AreaAbility
extends Ability
## A stomp or burst that hits everyone within "radius" of the user at once,
## pushing them away from the centre.


func _activate() -> void:
	var radius := float(stats.get("radius", 5.0))
	var center := user.global_position
	user.animate(str(stats.get("anim", "stomp")))
	Effects.ring(user.get_parent(), center + Vector3.UP * 0.1, radius,
		Color(str(stats.get("color", "#ffffff"))), 0.45)
	Effects.dust(user.get_parent(), center, radius * 0.3)
	Effects.area_hit(user, center, radius, {
		"damage": float(stats.get("damage", 10.0)),
		"knockback": float(stats.get("knockback", 0.0)),
		"slow": float(stats.get("slow", 0.0)),
		"slow_time": float(stats.get("slow_time", 0.0)),
	})


func reach() -> float:
	return float(stats.get("radius", 5.0))
