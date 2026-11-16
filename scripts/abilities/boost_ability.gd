class_name BoostAbility
extends Ability
## Air Scooter: ride a spinning ball of air for a few seconds, much faster and
## with higher jumps.


func _activate() -> void:
	var duration := float(stats.get("duration", 3.0))
	user.boost(duration, float(stats.get("speed_mult", 1.7)), float(stats.get("jump_mult", 1.3)))
	user.animate(str(stats.get("anim", "ride")), duration, true)
	var ball := Node3D.new()
	var sphere := Effects.mesh_instance(Effects.sphere(0.45), Effects.mat(Color(1, 1, 1, 0.3), 0.6))
	ball.add_child(sphere)
	for i in 3:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.38 + 0.05 * i
		torus.outer_radius = 0.46 + 0.05 * i
		var ring := Effects.mesh_instance(torus, Effects.mat(Color(1, 1, 1, 0.5), 0.5, true, true))
		ring.rotation = Vector3(i * 1.1, i * 0.7, 0)
		ball.add_child(ring)
	var swirl := Effects.emitter(Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0), {
		"amount": 24, "lifetime": 0.4, "size": 0.15, "speed": Vector2(1.0, 2.0), "spread": 180.0,
		"emit_radius": 0.45})
	swirl.emitting = true
	ball.add_child(swirl)
	ball.set_script(preload("res://scripts/spinner.gd"))
	Effects.attach(user, ball, duration, Vector3(0, 0.3, 0))
	Effects.gust(user.get_parent(), user.global_position + Vector3.UP * 0.3, 0.8)


func reach() -> float:
	return 0.0
