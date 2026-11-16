extends Node3D
## A defensive move that follows its caster: blocks enemy shots that come
## within "radius", pushes enemies out ("push" per second) and draws itself by
## "look" (air_sphere, fire_ring or rock_armor). Frees itself after "duration".

var caster: Node3D
var radius := 0.0
var push := 0.0
var duration := 2.0
var look := "air_sphere"
var _spin: Node3D
var _material: StandardMaterial3D


func setup(from: Node3D, stats: Dictionary) -> void:
	add_to_group("spawned")
	caster = from
	radius = float(stats.get("radius", 0.0))
	push = float(stats.get("push", 0.0))
	duration = float(stats.get("duration", 2.0))
	look = str(stats.get("look", "air_sphere"))
	_build()
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if _spin != null:
		_spin.rotate_y(6.0 * delta)
	if radius <= 0.0:
		return
	var center := caster.global_position + Vector3.UP * 1.0
	for node in get_tree().get_nodes_in_group("projectiles"):
		var shot := node as Projectile
		if shot == null or shot.shooter == caster:
			continue
		if shot.global_position.distance_to(center) < radius + shot.radius:
			shot.block()
	if push > 0.0:
		for target: Node3D in Effects.hittables(caster):
			var offset := target.global_position - caster.global_position
			offset.y = 0.0
			if offset.length() < radius and target is CharacterBody3D:
				(target as CharacterBody3D).move_and_collide(offset.normalized() * push * delta)


func _build() -> void:
	match look:
		"air_sphere":
			_material = Effects.mat(Color(0.9, 0.95, 1.0, 0.18), 0.4, true)
			var bubble := Effects.mesh_instance(Effects.sphere(radius, 24), _material)
			bubble.position.y = 1.0
			add_child(bubble)
			_spin = Node3D.new()
			_spin.position.y = 1.0
			add_child(_spin)
			for i in 3:
				var torus := TorusMesh.new()
				torus.inner_radius = radius * 0.92
				torus.outer_radius = radius * 0.97
				var ring := Effects.mesh_instance(torus, Effects.mat(Color(1, 1, 1, 0.45), 0.5, true))
				ring.rotation = Vector3(0.5 + i * 0.9, 0, i * 1.2)
				_spin.add_child(ring)
			var swirl := Effects.emitter(Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0), {
				"amount": 30, "lifetime": 0.5, "size": 0.18, "speed": Vector2(2.0, 4.0), "spread": 180.0,
				"emit_radius": radius * 0.9, "local": true})
			swirl.position.y = 1.0
			swirl.emitting = true
			add_child(swirl)
			Effects.gust(caster.get_parent(), caster.global_position + Vector3.UP, 1.0)
		"fire_ring":
			var flames := Effects.emitter(Color(1.0, 0.9, 0.5), Color(0.85, 0.1, 0.0, 0.0), {
				"amount": 120, "lifetime": 0.45, "size": 0.45, "speed": Vector2(5.0, 8.0),
				"direction": Vector3.UP, "spread": 90.0, "emit_radius": 0.4, "damping": 6.0,
				"gravity": Vector3(0, 3, 0), "one_shot": true, "explosiveness": 0.85, "end_scale": 1.4})
			flames.position.y = 0.4
			flames.emitting = true
			add_child(flames)
			var torus := TorusMesh.new()
			torus.inner_radius = 0.75
			torus.outer_radius = 1.0
			_material = Effects.mat(Color(1.0, 0.5, 0.1, 0.8), 3.0, true)
			var ring := Effects.mesh_instance(torus, _material)
			ring.position.y = 0.3
			add_child(ring)
			var tween := ring.create_tween().set_parallel()
			tween.tween_property(ring, "scale", Vector3(radius, 2.0, radius), duration * 0.8)
			tween.tween_property(_material, "albedo_color:a", 0.0, duration)
			Effects.flash(caster.get_parent(), caster.global_position + Vector3.UP, Color(1.0, 0.5, 0.2), 6.0, 8.0, duration)
		"rock_armor":
			var figure := caster.get("model") as StickFigure
			if figure != null:
				figure.add_armor(Color(0.5, 0.42, 0.32), duration)
			Effects.debris(caster.get_parent(), caster.global_position + Vector3.UP * 0.2, Color(0.55, 0.45, 0.32), 1.2)
			Effects.ring(caster.get_parent(), caster.global_position + Vector3.UP * 0.1, 4.0, Color(0.8, 0.65, 0.45), 0.45)
