class_name DashAbility
extends Ability
## Flame Dash and Air Leap: a burst of speed the way you are moving (or aiming,
## when standing still). "up" adds a jump; "invulnerable" ignores hits mid-dash.


func _activate() -> void:
	var direction: Vector3 = user.dash_direction()
	user.dash(direction, float(stats.get("dash_speed", 15.0)), float(stats.get("dash_time", 0.2)),
		float(stats.get("up", 0.0)), bool(stats.get("invulnerable", false)))
	Effects.ring(user.get_parent(), user.global_position + Vector3.UP * 0.1, 1.5,
		Color(str(stats.get("color", "#ffffff"))), 0.3)


func reach() -> float:
	return float(stats.get("dash_speed", 15.0)) * float(stats.get("dash_time", 0.2))
