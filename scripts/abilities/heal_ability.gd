class_name HealAbility
extends Ability
## Healing Water: heals "amount" HP over "duration" seconds while glowing water
## swirls up around you.


func _activate() -> void:
	var duration := float(stats.get("duration", 4.0))
	user.heal_over_time(float(stats.get("amount", 30.0)), duration)
	user.animate(str(stats.get("anim", "heal")), 0.9)
	var color := Color(str(stats.get("color", "#5fe0c8")))
	var swirl := Effects.emitter(Color(color.lightened(0.3), 0.9), Color(color, 0.0), {
		"amount": 40, "lifetime": 0.9, "size": 0.14, "speed": Vector2(0.8, 1.6), "direction": Vector3.UP,
		"spread": 15.0, "emit_radius": 0.55, "gravity": Vector3(0, 1.0, 0), "local": true})
	Effects.attach(user, swirl, duration, Vector3(0, 0.2, 0))
	for i in 2:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.5
		torus.outer_radius = 0.58
		var ring := Effects.mesh_instance(torus, Effects.mat(Color(color, 0.6), 1.5, true))
		ring.set_script(preload("res://scripts/rising_ring.gd"))
		ring.set("period", 1.2)
		ring.set("offset", i * 0.6)
		Effects.attach(user, ring, duration, Vector3.ZERO)
	Effects.ring(user.get_parent(), user.global_position + Vector3.UP * 0.1, 1.6, color, 0.6)


func reach() -> float:
	return 0.0
