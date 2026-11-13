class_name Projectile
extends Area3D
## One bending shot. An ability calls setup() right after adding it to the
## scene. It flies along the aim (up and down too, optionally arcing), hits
## the first body it touches and frees itself with an impact effect. Pierce
## shots pass through targets but still stop at walls. Extras from
## balance.json: explode_radius (splash damage), root_time (frozen in place),
## rise_time (pulled up out of the ground first), ground (rolls along the
## floor) and look (how it is drawn).

var shooter: Node3D
var velocity := Vector3.ZERO
var gravity_strength := 0.0
var lifetime := 1.0
var pierce := false
var ground := false
var look := "fire_bolt"
var color := Color.WHITE
var radius := 0.25
var explode_radius := 0.0
var explode_damage := 0.0
var hit_info: Dictionary = {}
var _already_hit: Array[Node] = []
var _visual: Node3D
var _spin_parts: Array[Node3D] = []
var _flicker: Array[Node3D] = []
var _rise_left := 0.0
var _rise_from := Vector3.ZERO
var _rise_to := Vector3.ZERO
var _rise_total := 0.0
var _age := 0.0
var _done := false


func _ready() -> void:
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)


func setup(from: Node3D, origin: Vector3, direction: Vector3, stats: Dictionary) -> void:
	shooter = from
	ground = bool(stats.get("ground", false))
	if ground:
		direction.y = 0.0
		direction = direction.normalized()
	var speed: float = float(stats.get("speed", 20.0))
	var launch_up: float = float(stats.get("launch_up", 0.0))
	velocity = direction * speed + Vector3.UP * launch_up
	gravity_strength = float(stats.get("gravity", 0.0))
	lifetime = float(stats.get("range", 20.0)) / maxf(speed, 0.1)
	pierce = bool(stats.get("pierce", false))
	look = str(stats.get("look", "fire_bolt"))
	color = Color(str(stats.get("color", "#ffffff")))
	radius = float(stats.get("radius", 0.25))
	explode_radius = float(stats.get("explode_radius", 0.0))
	explode_damage = float(stats.get("explode_damage", stats.get("damage", 5.0)))
	hit_info = {
		"damage": float(stats.get("damage", 5.0)),
		"knockback": float(stats.get("knockback", 0.0)),
		"slow": float(stats.get("slow", 0.0)),
		"slow_time": float(stats.get("slow_time", 0.0)),
		"root_time": float(stats.get("root_time", 0.0)),
		"launch": float(stats.get("launch", 0.0)),
	}
	_rise_total = float(stats.get("rise_time", 0.0))
	if _rise_total > 0.0:
		# Pull the shot up out of the floor before it flies.
		_rise_left = _rise_total
		_rise_to = origin
		_rise_from = Vector3(origin.x, (from.global_position.y if from != null else origin.y) - radius, origin.z)
		monitoring = false
		global_position = _rise_from
		Effects.dust(get_parent(), _rise_from + Vector3.UP * 0.1, 0.5 + radius)
	else:
		global_position = origin
	var shape := SphereShape3D.new()
	shape.radius = radius
	$CollisionShape3D.shape = shape
	_build_look()
	_orient()


func _physics_process(delta: float) -> void:
	_age += delta
	if _rise_left > 0.0:
		_rise_left -= delta
		var t := 1.0 - maxf(_rise_left, 0.0) / _rise_total
		global_position = _rise_from.lerp(_rise_to, ease(t, 0.4))
		if _rise_left <= 0.0:
			monitoring = true
		_animate(delta)
		return
	velocity.y -= gravity_strength * delta
	global_position += velocity * delta
	lifetime -= delta
	_animate(delta)
	if lifetime <= 0.0:
		_finish(global_position, null)


func _animate(delta: float) -> void:
	_orient()
	for part in _spin_parts:
		part.rotate_object_local(Vector3.FORWARD, 9.0 * delta)
	for part in _flicker:
		var f := 1.0 + sin(_age * 40.0 + part.get_index()) * 0.12 + randf_range(-0.06, 0.06)
		part.scale = Vector3.ONE * f


func _orient() -> void:
	if _visual == null or velocity.length_squared() < 0.001:
		return
	var forward := velocity.normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.BACK
	_visual.global_basis = Basis.looking_at(forward, up)
	if look in ["rock", "boulder", "ice_prison"]:
		_visual.rotate_object_local(Vector3.RIGHT, -_age * 8.0)


func _on_body_entered(body: Node3D) -> void:
	if _done or body == shooter or body in _already_hit:
		return
	if ground and body.is_in_group("floor"):
		return
	if body.has_method("take_hit"):
		_already_hit.append(body)
		var hit := hit_info.duplicate()
		hit["direction"] = _push_direction(body)
		hit["attacker"] = shooter
		body.take_hit(hit)
		if pierce:
			Effects.impact(get_parent(), global_position, look, color, 0.5)
			return
	_finish(global_position, body)


## Blocked by a shield: burst harmlessly.
func block() -> void:
	if _done:
		return
	_done = true
	Effects.impact(get_parent(), global_position, look, color, 0.6)
	queue_free()


func _push_direction(body: Node3D) -> Vector3:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 0.1 and shooter != null:
		flat = body.global_position - shooter.global_position
		flat.y = 0.0
	return flat.normalized()


func _finish(at: Vector3, direct: Node3D) -> void:
	if _done:
		return
	_done = true
	var size := clampf(radius * 2.5, 0.6, 2.0)
	if explode_radius > 0.0:
		size = explode_radius * 0.8
		for target: Node3D in Effects.hittables(shooter):
			if target == direct or target in _already_hit:
				continue
			var offset := target.global_position + Vector3.UP * 0.9 - at
			if offset.length() > explode_radius:
				continue
			var hit := hit_info.duplicate()
			hit["damage"] = explode_damage
			var flat := Vector3(offset.x, 0.0, offset.z)
			hit["direction"] = flat.normalized() if flat.length() > 0.05 else _push_direction(target)
			hit["attacker"] = shooter
			target.take_hit(hit)
		Effects.ring(get_parent(), Vector3(at.x, maxf(at.y - 0.8, 0.05), at.z), explode_radius,
			color, 0.35)
	Effects.impact(get_parent(), at, look, color, size)
	queue_free()


# --- Looks ---------------------------------------------------------------------

func _build_look() -> void:
	$MeshInstance3D.visible = false
	_visual = Node3D.new()
	add_child(_visual)
	match look:
		"fire_bolt", "fireball":
			_fire_look(look == "fireball")
		"fire_arc":
			_arc_look(Color(1.0, 0.55, 0.15), 2.2, 75.0, true)
			_trail(Color(1.0, 0.8, 0.3), Color(0.9, 0.15, 0.0, 0.0), 30, 0.3, radius * 2.0, Vector3(0, 2, 0))
			_light(Color(1.0, 0.5, 0.2), 1.5)
		"water_whip":
			_stream_look()
		"water_arc":
			_arc_look(Color(color, 0.7), 2.0, 70.0, false)
			_trail(Color(0.75, 0.9, 1.0, 0.9), Color(color, 0.0), 24, 0.45, radius * 1.5, Vector3(0, -9, 0))
		"ice_shard":
			var shard := Effects.mesh_instance(Effects.cone(radius * 1.1, radius * 6.0, 5),
				Effects.mat(Color(0.85, 0.97, 1.0, 0.85), 0.8))
			shard.rotation.x = -PI * 0.5
			_visual.add_child(shard)
			_trail(Color(1, 1, 1, 0.8), Color(0.7, 0.9, 1.0, 0.0), 14, 0.3, radius, Vector3.ZERO)
		"ice_prison":
			var core := Effects.mesh_instance(Effects.sphere(radius * 1.3, 6), Effects.mat(Color(0.75, 0.95, 1.0, 0.8), 1.0))
			_visual.add_child(core)
			for i in 4:
				var spike := Effects.mesh_instance(Effects.cone(radius * 0.4, radius * 2.2, 4),
					Effects.mat(Color(0.9, 1.0, 1.0, 0.9), 0.6))
				spike.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
				core.add_child(spike)
			_trail(Color(1, 1, 1, 0.8), Color(0.6, 0.9, 1.0, 0.0), 24, 0.4, radius, Vector3(0, -1, 0))
		"rock", "boulder":
			_rock_look(look == "boulder")
		"air_puff":
			_air_rings(4, Color(1, 1, 1, 0.35))
			_trail(Color(1, 1, 1, 0.5), Color(0.9, 0.95, 1.0, 0.0), 20, 0.3, radius * 0.8, Vector3.ZERO, 2.0)
		"air_ball":
			var ball := Effects.mesh_instance(Effects.sphere(radius * 1.2), Effects.mat(Color(1, 1, 1, 0.3), 0.5))
			_visual.add_child(ball)
			_air_rings(3, Color(1, 1, 1, 0.45))
			_trail(Color(1, 1, 1, 0.55), Color(0.9, 0.95, 1.0, 0.0), 24, 0.35, radius, Vector3.ZERO, 2.5)
		"air_blade":
			_arc_look(Color(1, 1, 1, 0.55), 2.6, 60.0, false)
			_trail(Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.0), 16, 0.2, radius * 1.5, Vector3.ZERO)
		"wave":
			_wave_look()
		_:
			var s := Effects.mesh_instance(Effects.sphere(radius * 1.3), Effects.mat(color, 1.0))
			_visual.add_child(s)


func _fire_look(big: bool) -> void:
	var core := Effects.mesh_instance(Effects.sphere(radius * 0.75), Effects.mat(Color(1.0, 0.95, 0.7), 3.0, true))
	_visual.add_child(core)
	var shell := Effects.mesh_instance(Effects.sphere(radius * 1.35), Effects.mat(Color(1.0, 0.45, 0.1, 0.55), 2.0, true))
	_visual.add_child(shell)
	_flicker.append(shell)
	var tail := Effects.mesh_instance(Effects.cone(radius * 1.0, radius * (6.0 if big else 4.0), 8),
		Effects.mat(Color(1.0, 0.35, 0.05, 0.45), 2.0, true))
	tail.rotation.x = PI * 0.5
	tail.position.z = radius * (3.0 if big else 2.0)
	_visual.add_child(tail)
	_flicker.append(tail)
	_trail(Color(1.0, 0.85, 0.35), Color(0.8, 0.1, 0.0, 0.0), 40 if big else 22, 0.35 if big else 0.25,
		radius * 1.7, Vector3(0, 2.5, 0))
	if big:
		_trail(Color(0.25, 0.22, 0.2, 0.5), Color(0.2, 0.2, 0.2, 0.0), 14, 0.8, radius * 1.4, Vector3(0, 1.0, 0))
	_light(Color(1.0, 0.5, 0.2), 3.0 if big else 1.4)


func _arc_look(arc_color: Color, size: float, angle: float, hot: bool) -> void:
	var arc := Effects.mesh_instance(Effects.arc_mesh(radius * size, angle, radius * 1.1),
		Effects.mat(arc_color, 2.5 if hot else 0.6, hot, true))
	_visual.add_child(arc)
	_flicker.append(arc)
	if hot:
		var inner := Effects.mesh_instance(Effects.arc_mesh(radius * size * 0.95, angle * 0.8, radius * 0.5),
			Effects.mat(Color(1.0, 0.95, 0.7), 3.0, true, true))
		inner.position.y = 0.01
		_visual.add_child(inner)


func _stream_look() -> void:
	var water := Effects.mat(Color(color, 0.7), 0.6)
	for i in 4:
		var blob := Effects.mesh_instance(Effects.sphere(radius * (1.15 - 0.2 * i), 10), water)
		blob.position.z = i * radius * 1.3
		blob.scale = Vector3(1.0, 1.0, 1.6)
		_visual.add_child(blob)
		_flicker.append(blob)
	var core := Effects.mesh_instance(Effects.sphere(radius * 0.5), Effects.mat(Color(0.85, 0.95, 1.0, 0.8), 1.0))
	_visual.add_child(core)
	_trail(Color(0.75, 0.9, 1.0, 0.9), Color(color, 0.0), 20, 0.45, radius, Vector3(0, -9, 0))


func _rock_look(big: bool) -> void:
	var stone := Effects.mat(color)
	var main := Effects.mesh_instance(Effects.sphere(radius * 1.15, 6) if big else Effects.box(Vector3.ONE * radius * 1.6), stone)
	main.rotation = Vector3(randf(), randf(), randf()) * TAU
	main.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_visual.add_child(main)
	for i in (4 if big else 2):
		var chunk := Effects.mesh_instance(Effects.box(Vector3.ONE * radius * randf_range(0.6, 0.9)), Effects.mat(color.darkened(0.15)))
		chunk.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * radius * 0.8
		chunk.rotation = Vector3(randf(), randf(), randf()) * TAU
		main.add_child(chunk)
	_trail(Color(0.6, 0.5, 0.38, 0.6), Color(0.6, 0.55, 0.45, 0.0), 16 if big else 8, 0.5, radius * 1.2,
		Vector3(0, -2, 0))


func _air_rings(count: int, ring_color: Color) -> void:
	for i in count:
		var torus := TorusMesh.new()
		torus.inner_radius = radius * (0.55 + 0.1 * i)
		torus.outer_radius = radius * (0.7 + 0.1 * i)
		torus.rings = 16
		torus.ring_segments = 6
		var ring := Effects.mesh_instance(torus, Effects.mat(ring_color, 0.4, true, true))
		ring.rotation.x = PI * 0.5
		ring.position.z = i * radius * 0.6
		var holder := Node3D.new()
		holder.add_child(ring)
		_visual.add_child(holder)
		_spin_parts.append(holder)


func _wave_look() -> void:
	var wave := Effects.mesh_instance(Effects.wave_mesh(radius * 3.2, radius * 1.9, radius * 1.1),
		Effects.mat(Color(color, 0.72), 0.5, false, true))
	wave.position = Vector3(0, -radius * 0.9, radius * 0.3)
	_visual.add_child(wave)
	var foam := Effects.emitter(Color(1, 1, 1, 0.9), Color(0.8, 0.9, 1.0, 0.0), {
		"amount": 50, "lifetime": 0.6, "size": 0.25, "emit_radius": radius * 1.3,
		"speed": Vector2(1.0, 3.0), "gravity": Vector3(0, -6, 0), "direction": Vector3.UP, "spread": 50.0})
	foam.position = Vector3(0, radius * 0.8, 0)
	foam.emitting = true
	_visual.add_child(foam)
	_light(Color(0.4, 0.7, 1.0), 1.0)


func _trail(from: Color, to: Color, amount: int, life: float, emit_radius: float, gravity: Vector3,
		end_scale := 0.15) -> void:
	var p := Effects.emitter(from, to, {
		"amount": amount, "lifetime": life, "size": maxf(radius * 1.2, 0.12), "emit_radius": emit_radius,
		"speed": Vector2(0.2, 1.0), "gravity": gravity, "spread": 180.0, "end_scale": end_scale})
	p.emitting = true
	add_child(p)


func _light(light_color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = light_color
	light.light_energy = energy
	light.omni_range = 3.0 + radius * 4.0
	add_child(light)
