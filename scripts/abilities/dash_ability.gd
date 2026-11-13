class_name DashAbility
extends Ability
## Jet Dash: a burst of speed the way you are moving (or aiming, when standing
## still). "up" adds a jump; "invulnerable" ignores hits mid-dash. Fire
## leaves a trail of flame behind your feet.


func _activate() -> void:
	var direction: Vector3 = user.dash_direction()
	var dash_time := float(stats.get("dash_time", 0.2))
	user.dash(direction, float(stats.get("dash_speed", 15.0)), dash_time,
		float(stats.get("up", 0.0)), bool(stats.get("invulnerable", false)))
	user.animate(str(stats.get("anim", "dash")), dash_time + 0.15)
	var color := Color(str(stats.get("color", "#ffffff")))
	if user.element == "fire":
		var jet := Effects.emitter(Color(1.0, 0.9, 0.5), Color(0.8, 0.1, 0.0, 0.0), {
			"amount": 60, "lifetime": 0.4, "size": 0.35, "speed": Vector2(1.0, 3.0),
			"direction": Vector3.DOWN, "spread": 30.0, "emit_radius": 0.2, "gravity": Vector3(0, 2, 0)})
		Effects.attach(user, jet, dash_time + 0.05, Vector3(0, 0.15, 0))
		Effects.flash(user.get_parent(), user.global_position, Color(1.0, 0.55, 0.2), 3.0, 5.0, 0.3)
	else:
		Effects.gust(user.get_parent(), user.global_position + Vector3.UP * 0.2, 0.7)
	Effects.ring(user.get_parent(), user.global_position + Vector3.UP * 0.1, 1.5, color, 0.3)


func reach() -> float:
	return float(stats.get("dash_speed", 15.0)) * float(stats.get("dash_time", 0.2))
